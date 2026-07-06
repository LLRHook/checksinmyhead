#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

def require_env(name)
  value = ENV[name]
  abort "Missing required environment variable: #{name}" if value.nil? || value.empty?
  value
end

KEY_ID = require_env("ASC_KEY_ID")
ISSUER_ID = require_env("ASC_ISSUER_ID")
KEY_PATH = require_env("ASC_KEY_PATH")
APP_ID = require_env("ASC_APP_ID")
BUILD_NUMBER = require_env("BUILD_NUMBER")
GROUP_NAME = ENV.fetch("TESTFLIGHT_GROUP_NAME", "Victor Internal")

def b64url(value)
  Base64.urlsafe_encode64(value).delete("=")
end

def jwt_token
  header = { alg: "ES256", kid: KEY_ID, typ: "JWT" }
  payload = {
    iss: ISSUER_ID,
    iat: Time.now.to_i - 60,
    exp: Time.now.to_i + 20 * 60,
    aud: "appstoreconnect-v1"
  }

  signing_input = [b64url(JSON.generate(header)), b64url(JSON.generate(payload))].join(".")
  key = OpenSSL::PKey.read(File.read(KEY_PATH))
  der_signature = key.sign("SHA256", signing_input)
  asn1 = OpenSSL::ASN1.decode(der_signature)
  r = asn1.value[0].value.to_s(2).rjust(32, "\0")[-32, 32]
  s = asn1.value[1].value.to_s(2).rjust(32, "\0")[-32, 32]

  "#{signing_input}.#{b64url(r + s)}"
end

TOKEN = jwt_token

def query(path, params)
  "#{path}?#{URI.encode_www_form(params)}"
end

def asc_request(method, path, body: nil, allow_failure: false)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request_class = case method
                  when :get then Net::HTTP::Get
                  when :post then Net::HTTP::Post
                  when :patch then Net::HTTP::Patch
                  else abort "Unsupported method: #{method}"
                  end

  request = request_class.new(uri)
  request["Authorization"] = "Bearer #{TOKEN}"
  request["Content-Type"] = "application/json" if body
  request.body = JSON.generate(body) if body

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  unless response.code.to_i.between?(200, 299)
    warn "ASC #{method.to_s.upcase} #{path} failed with HTTP #{response.code}"
    warn response.body.to_s[0, 4000]
    return nil if allow_failure

    exit 1
  end

  response.body.nil? || response.body.empty? ? {} : JSON.parse(response.body)
end

def latest_build
  response = asc_request(:get, query("/v1/apps/#{APP_ID}/builds", {
    "fields[builds]" => "version,processingState,expired,uploadedDate,usesNonExemptEncryption",
    "limit" => "200"
  }))

  response.fetch("data").find do |build|
    build.dig("attributes", "version").to_s == BUILD_NUMBER
  end
end

def beta_groups
  response = asc_request(:get, query("/v1/apps/#{APP_ID}/betaGroups", {
    "fields[betaGroups]" => "name,isInternalGroup,publicLinkEnabled,publicLinkLimit,publicLinkLimitEnabled",
    "limit" => "200"
  }))
  response.fetch("data")
end

def create_beta_group(build_id)
  body = {
    data: {
      type: "betaGroups",
      attributes: {
        name: GROUP_NAME,
        publicLinkEnabled: false
      },
      relationships: {
        app: {
          data: { type: "apps", id: APP_ID }
        },
        builds: {
          data: [{ type: "builds", id: build_id }]
        }
      }
    }
  }

  asc_request(:post, "/v1/betaGroups", body: body).fetch("data")
end

def attach_build_to_group(group_id, build_id)
  body = {
    data: [{ type: "builds", id: build_id }]
  }

  asc_request(:post, "/v1/betaGroups/#{group_id}/relationships/builds", body: body, allow_failure: true)
end

def group_builds(group_id)
  response = asc_request(:get, query("/v1/betaGroups/#{group_id}/builds", {
    "fields[builds]" => "version,processingState,expired,uploadedDate,usesNonExemptEncryption",
    "limit" => "200"
  }))
  response.fetch("data")
end

build = latest_build
abort "Unable to find processed build #{BUILD_NUMBER} for App Store Connect app #{APP_ID}" unless build

build_id = build.fetch("id")
build_attributes = build.fetch("attributes")
puts "Found build #{build_attributes.fetch("version")} (#{build_id})"
puts "Build processingState=#{build_attributes["processingState"]} expired=#{build_attributes["expired"]} usesNonExemptEncryption=#{build_attributes["usesNonExemptEncryption"]}"

groups = beta_groups
group = groups.find { |item| item.dig("attributes", "isInternalGroup") && item.dig("attributes", "name") == GROUP_NAME }
group ||= groups.find { |item| item.dig("attributes", "isInternalGroup") }
group ||= groups.find { |item| item.dig("attributes", "name") == GROUP_NAME }

unless group
  puts "No beta group found; creating #{GROUP_NAME}"
  group = create_beta_group(build_id)
end

group_id = group.fetch("id")
group_attributes = group.fetch("attributes")
puts "Using beta group #{group_attributes["name"]} (#{group_id}) internal=#{group_attributes["isInternalGroup"]} publicLinkEnabled=#{group_attributes["publicLinkEnabled"]}"

attach_build_to_group(group_id, build_id)

attached = group_builds(group_id)
matching = attached.find { |item| item.fetch("id") == build_id }
abort "Build #{BUILD_NUMBER} was not attached to beta group #{group_id}" unless matching

puts "Build #{BUILD_NUMBER} is attached to beta group #{group_attributes["name"]}"
puts "TESTFLIGHT_GROUP_ID=#{group_id}"

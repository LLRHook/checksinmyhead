#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "net/http"
require "openssl"
require "time"
require "tmpdir"
require "uri"

def require_env(name)
  value = ENV[name]
  abort "Missing required environment variable: #{name}" if value.nil? || value.empty?
  value
end

KEY_ID = require_env("ASC_KEY_ID")
ISSUER_ID = require_env("ASC_ISSUER_ID")
KEY_PATH = require_env("ASC_KEY_PATH")
BUNDLE_ID = require_env("BUNDLE_ID")
APP_NAME = require_env("APP_NAME")
SKU = require_env("APP_SKU")
PROFILE_NAME = "#{APP_NAME} App Store #{Time.now.utc.strftime("%Y%m%d%H%M%S")}"

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

def asc_request(method, path, body: nil, allow_failure: false)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request_class = case method
                  when :get then Net::HTTP::Get
                  when :post then Net::HTTP::Post
                  when :delete then Net::HTTP::Delete
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
    warn response.body.to_s[0, 2000]
    return nil if allow_failure

    exit 1
  end

  response.body.nil? || response.body.empty? ? {} : JSON.parse(response.body)
end

def query(path, params)
  "#{path}?#{URI.encode_www_form(params)}"
end

def find_bundle
  response = asc_request(:get, query("/v1/bundleIds", {
    "filter[identifier]" => BUNDLE_ID,
    "limit" => "1"
  }))
  response.fetch("data").first
end

def create_bundle
  body = {
    data: {
      type: "bundleIds",
      attributes: {
        identifier: BUNDLE_ID,
        name: APP_NAME,
        platform: "IOS"
      }
    }
  }

  asc_request(:post, "/v1/bundleIds", body: body).fetch("data")
end

def find_or_create_bundle
  bundle = find_bundle
  return bundle if bundle

  puts "Creating bundle ID #{BUNDLE_ID}"
  create_bundle
end

def find_app
  response = asc_request(:get, query("/v1/apps", {
    "filter[bundleId]" => BUNDLE_ID,
    "limit" => "1"
  }))
  response.fetch("data").first
end

def create_app_with_name(name, sku)
  body = {
    data: {
      type: "apps",
      attributes: {
        name: name,
        bundleId: BUNDLE_ID,
        sku: sku,
        primaryLocale: "en-US",
        platform: "IOS"
      }
    }
  }

  asc_request(:post, "/v1/apps", body: body, allow_failure: true)
end

def find_or_create_app
  app = find_app
  return app if app

  puts "Creating App Store Connect app record for #{BUNDLE_ID}"
  response = create_app_with_name(APP_NAME, SKU)
  response ||= create_app_with_name("#{APP_NAME} #{Time.now.utc.strftime("%Y%m%d%H%M")}", "#{SKU}-#{Time.now.utc.strftime("%Y%m%d%H%M")}")
  abort "Unable to create App Store Connect app record for #{BUNDLE_ID}" unless response

  response.fetch("data")
end

def distribution_certificates
  response = asc_request(:get, query("/v1/certificates", {
    "limit" => "200"
  }))

  response.fetch("data").select do |certificate|
    type = certificate.dig("attributes", "certificateType").to_s
    type.include?("DISTRIBUTION")
  end
end

def create_profile(bundle_id, certificates)
  certificate_relationships = certificates.map do |certificate|
    { type: "certificates", id: certificate.fetch("id") }
  end

  body = {
    data: {
      type: "profiles",
      attributes: {
        name: PROFILE_NAME,
        profileType: "IOS_APP_STORE"
      },
      relationships: {
        bundleId: {
          data: { type: "bundleIds", id: bundle_id }
        },
        certificates: {
          data: certificate_relationships
        }
      }
    }
  }

  asc_request(:post, "/v1/profiles", body: body).fetch("data")
end

bundle = find_or_create_bundle
app = find_or_create_app
certificates = distribution_certificates
abort "No distribution certificates are available in App Store Connect" if certificates.empty?

puts "Using #{certificates.count} distribution certificate relationship(s)"
profile = create_profile(bundle.fetch("id"), certificates)
profile_attributes = profile.fetch("attributes")
profile_uuid = profile_attributes.fetch("uuid")
profile_content = profile_attributes.fetch("profileContent")
profile_path = File.join(ENV.fetch("RUNNER_TEMP", Dir.tmpdir), "#{profile_uuid}.mobileprovision")

File.binwrite(profile_path, Base64.decode64(profile_content))

if ENV["GITHUB_OUTPUT"]
  File.open(ENV.fetch("GITHUB_OUTPUT"), "a") do |file|
    file.puts "profile_uuid=#{profile_uuid}"
    file.puts "profile_path=#{profile_path}"
    file.puts "apple_id=#{app.fetch("id")}"
  end
end

puts "Prepared bundle #{BUNDLE_ID}"
puts "Prepared App Store Connect app id #{app.fetch("id")}"
puts "Created provisioning profile #{profile_uuid}"

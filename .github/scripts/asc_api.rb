# frozen_string_literal: true

# Minimal App Store Connect API client.
#
# Deliberately stdlib-only: no fastlane, no gems, nothing to install on the
# runner. Ruby ships with the GitHub macOS images, so this runs as-is.
#
# Auth is an ES256 JWT signed with the .p8 private key downloaded from
# App Store Connect. Apple rejects tokens older than 20 minutes.

require "base64"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

module ASC
  HOST = "api.appstoreconnect.apple.com"

  class Error < StandardError; end

  module_function

  def require_env(name)
    value = ENV[name]
    raise Error, "Missing required environment variable: #{name}" if value.nil? || value.empty?

    value
  end

  def b64url(value)
    Base64.urlsafe_encode64(value).delete("=")
  end

  # Apple wants a JOSE ES256 signature (raw r||s, 64 bytes), but OpenSSL hands
  # back DER. Unpack the ASN.1 sequence and left-pad each half to 32 bytes.
  def token
    @token ||= begin
      key_id = require_env("ASC_KEY_ID")
      issuer_id = require_env("ASC_ISSUER_ID")
      key_path = require_env("ASC_KEY_PATH")

      header = { alg: "ES256", kid: key_id, typ: "JWT" }
      payload = {
        iss: issuer_id,
        iat: Time.now.to_i - 60,
        exp: Time.now.to_i + 19 * 60,
        aud: "appstoreconnect-v1"
      }

      signing_input = [b64url(JSON.generate(header)), b64url(JSON.generate(payload))].join(".")
      pkey = OpenSSL::PKey.read(File.read(key_path))
      asn1 = OpenSSL::ASN1.decode(pkey.sign("SHA256", signing_input))
      r = asn1.value[0].value.to_s(2).rjust(32, "\0")[-32, 32]
      s = asn1.value[1].value.to_s(2).rjust(32, "\0")[-32, 32]

      "#{signing_input}.#{b64url(r + s)}"
    end
  end

  def query(path, params)
    "#{path}?#{URI.encode_www_form(params)}"
  end

  def request(method, path, body: nil, allow_failure: false)
    uri = URI("https://#{HOST}#{path}")
    klass = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      patch: Net::HTTP::Patch,
      delete: Net::HTTP::Delete
    }.fetch(method) { raise Error, "Unsupported method: #{method}" }

    req = klass.new(uri)
    req["Authorization"] = "Bearer #{token}"
    if body
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body)
    end

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) do |http|
      http.request(req)
    end

    code = response.code.to_i
    unless code.between?(200, 299)
      warn "ASC #{method.to_s.upcase} #{path} -> HTTP #{code}"
      warn response.body.to_s[0, 4000]
      return nil if allow_failure

      raise Error, "App Store Connect request failed: #{method.to_s.upcase} #{path} (HTTP #{code})"
    end

    return {} if response.body.nil? || response.body.empty?

    JSON.parse(response.body)
  end

  def get(path, params = {}, allow_failure: false)
    request(:get, params.empty? ? path : query(path, params), allow_failure: allow_failure)
  end

  def post(path, body, allow_failure: false)
    request(:post, path, body: body, allow_failure: allow_failure)
  end

  def patch(path, body, allow_failure: false)
    request(:patch, path, body: body, allow_failure: allow_failure)
  end

  def delete(path, allow_failure: false)
    request(:delete, path, allow_failure: allow_failure)
  end

  # --- Convenience lookups -------------------------------------------------

  def find_app(bundle_id)
    response = get("/v1/apps", { "filter[bundleId]" => bundle_id, "limit" => "1" })
    app = response.fetch("data", []).first
    raise Error, "No app found in App Store Connect for bundle ID #{bundle_id}" unless app

    app
  end

  # Builds are identified by CFBundleVersion, exposed as the `version`
  # attribute. Apple does not offer a filter for it, so page and match.
  def find_build(app_id, build_number)
    response = get("/v1/builds", {
      "filter[app]" => app_id,
      "fields[builds]" => "version,processingState,expired,uploadedDate",
      "limit" => "200",
      "sort" => "-uploadedDate"
    })

    response.fetch("data", []).find do |build|
      build.dig("attributes", "version").to_s == build_number.to_s && !build.dig("attributes", "expired")
    end
  end

  # Poll until App Store Connect finishes processing the upload. A build stays
  # PROCESSING for a few minutes after altool reports a successful delivery.
  def wait_for_build(app_id, build_number, timeout_seconds: 2700, interval: 30)
    deadline = Time.now + timeout_seconds
    last_state = nil

    loop do
      build = find_build(app_id, build_number)
      state = build&.dig("attributes", "processingState")

      if state != last_state
        puts "Build #{build_number}: #{state || 'not yet visible'}"
        last_state = state
      end

      case state
      when "VALID"
        return build
      when "INVALID"
        raise Error, "Build #{build_number} was rejected during processing (state INVALID). " \
                     "Check App Store Connect for the rejection reason."
      end

      raise Error, "Timed out after #{timeout_seconds}s waiting for build #{build_number} to process" if Time.now > deadline

      sleep interval
    end
  end
end

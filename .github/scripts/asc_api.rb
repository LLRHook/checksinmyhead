# frozen_string_literal: true

# Stdlib ASC transport. Direct callers retain GET access only. Mutations require
# the process-local capability installed by the verified delivery entry point.
require "base64"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"
require "timeout"

module ASC
  HOST = "api.appstoreconnect.apple.com"
  MAX_BODY = 2 * 1024 * 1024
  class Error < StandardError; end
  class RequestError < Error
    attr_reader :status
    def initialize(status)
      @status = status
      super("ASC request failed (HTTP #{status})")
    end
  end

  module_function

  def require_env(name)
    value = ENV[name]
    raise Error, "Missing required environment variable: #{name}" if value.nil? || value.empty?
    value
  end

  def identifier(value)
    raise Error, "Invalid ASC identifier" unless value.is_a?(String) && value.match?(/\A[A-Za-z0-9-]{1,100}\z/)
    value
  end

  def build_number(value)
    raise Error, "Invalid build number" unless value.is_a?(String) && value.match?(/\A[0-9]+(?:\.[0-9]+){0,2}\z/)
    value
  end

  def b64url(value)
    Base64.urlsafe_encode64(value).delete("=")
  end

  def token
    now = Time.now.to_i
    return @token if @token && @token_expires && now < @token_expires - 60
    key_id = require_env("ASC_KEY_ID")
    issuer_id = require_env("ASC_ISSUER_ID")
    @token_expires = now + 19 * 60
    header = { alg: "ES256", kid: key_id, typ: "JWT" }
    payload = { iss: issuer_id, iat: now - 60, exp: @token_expires, aud: "appstoreconnect-v1" }
    signing_input = [b64url(JSON.generate(header)), b64url(JSON.generate(payload))].join(".")
    key = OpenSSL::PKey.read(ENV["DELIVERY_ASC_API_KEY_P8"] || File.read(require_env("ASC_KEY_PATH")))
    asn1 = OpenSSL::ASN1.decode(key.sign("SHA256", signing_input))
    r, s = asn1.value.map { |n| n.value.to_s(2).rjust(32, "\0")[-32, 32] }
    @token = "#{signing_input}.#{b64url(r + s)}"
  end

  def query(path, params)
    "#{path}?#{URI.encode_www_form(params)}"
  end

  def local_path(value)
    uri = URI(value)
    if uri.host
      raise Error, "Untrusted ASC pagination URL" unless uri.scheme == "https" && uri.host == HOST && uri.port == 443 && !uri.userinfo && !uri.fragment
    else
      raise Error, "Untrusted ASC path" unless value.start_with?("/v1/") && !value.start_with?("//")
    end
    path = uri.path + (uri.query ? "?#{uri.query}" : "")
    raise Error, "Untrusted ASC path" unless path.start_with?("/v1/") && !path.match?(/[\x00-\x20\x7f\\]/) && !path.include?("..") && !uri.fragment
    path
  rescue URI::InvalidURIError
    raise Error, "Invalid ASC path"
  end

  def http_request(method, path, body)
    uri = URI("https://#{HOST}#{path}")
    klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }.fetch(method)
    req = klass.new(uri)
    req["Authorization"] = "Bearer #{token}"
    if body
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body)
    end
    status = nil
    raw = +""
    Timeout.timeout(120) do
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 60, write_timeout: 30) do |http|
      http.max_retries = 0 # Never implicitly retry an ASC mutation.
      http.request(req) do |response|
        status = response.code.to_i
        response.read_body do |part|
          raise Error, "ASC response too large" if raw.bytesize + part.bytesize > MAX_BODY
          raw << part
        end
      end
    end
    end
    [status, raw]
  rescue Error
    raise
  rescue StandardError
    raise Error, "ASC transport failed" # No URLs, headers, keys or raw error payloads.
  end

  def with_write_authority(authorizer)
    raise Error, "Invalid/nested ASC authority" unless authorizer.respond_to?(:call) && @write_authorizer.nil?
    @write_authorizer = authorizer
    yield
  ensure
    @write_authorizer = nil
  end

  def request(method, path, body: nil, allow_failure: false)
    raise Error, "Unsupported ASC method" unless %i[get post patch delete].include?(method)
    raise Error, "ASC writes require verified delivery authority" if method != :get && !@write_authorizer
    path = local_path(path)
    @write_authorizer.call(method, path, body) if method != :get
    code, raw = http_request(method, path, body)
    unless code.between?(200, 299)
      # Preserve typed status decisions; optional legacy probes only handle the
      # documented validation/conflict failures. Auth, throttling and 5xx fail.
      return nil if allow_failure && [400, 404, 409, 422].include?(code)
      raise RequestError, code
    end
    result = raw.nil? || raw.empty? ? {} : JSON.parse(raw)
    @write_authorizer.observe(method, path, result) if @write_authorizer&.respond_to?(:observe)
    result
  rescue JSON::ParserError
    raise Error, "Malformed ASC JSON"
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

  def pages(path, params = {}, allow_failure: false)
    next_path = params.empty? ? local_path(path) : query(local_path(path), params)
    base = URI("https://#{HOST}#{next_path}").path
    result = []; seen = {}; visited = {}
    20.times do
      raise Error, "Cyclic ASC pagination" if visited[next_path]
      visited[next_path] = true
      response = get(next_path, {}, allow_failure: allow_failure)
      return nil unless response
      data = response["data"]
      raise Error, "Malformed ASC collection" unless data.is_a?(Array)
      data.each do |row|
        id = identifier(row.fetch("id"))
        raise Error, "Duplicate ASC collection identity" if seen[id]
        seen[id] = true; result << row
      end
      link = response.dig("links", "next")
      return result if link.nil?
      next_path = local_path(link)
      raise Error, "ASC pagination changed collection" unless URI("https://#{HOST}#{next_path}").path == base
    end
    raise Error, "ASC pagination limit reached"
  end

  def find_app(bundle_id)
    apps = pages("/v1/apps", { "filter[bundleId]" => bundle_id, "limit" => "200" })
    raise Error, "Missing/ambiguous ASC app" unless apps.length == 1 && apps[0].dig("attributes", "bundleId") == bundle_id
    apps[0]
  end

  # Number allocation and exact build lookup both exhaust the bounded collection.
  def all_builds(app_id)
    pages("/v1/builds", { "filter[app]" => identifier(app_id), "limit" => "200", "sort" => "-uploadedDate" })
  end

  def find_build(app_id, number, version_string:)
    number = build_number(number)
    matches = all_builds(app_id).select { |b| b.dig("attributes", "version") == number }
    # Do not select a first/latest match. Even an ineligible duplicate is ambiguous.
    raise Error, "Ambiguous ASC build number" if matches.length > 1
    return nil if matches.empty?
    read_build(matches[0].fetch("id"), app_id: app_id, number: number, version_string: version_string, eligible: false)
  end

  def read_build(id, app_id:, number:, version_string:, eligible: true, now: Time.now)
    id = identifier(id); identifier(app_id); build_number(number)
    build = get("/v1/builds/#{id}").fetch("data")
    app = get("/v1/builds/#{id}/app").fetch("data")
    prerelease = get("/v1/builds/#{id}/preReleaseVersion").fetch("data")
    a = build.fetch("attributes")
    raise Error, "ASC exact build/app/platform/version mismatch" unless build["type"] == "builds" && build["id"] == id &&
      app["type"] == "apps" && app["id"] == app_id && a["version"] == number &&
      prerelease["type"] == "preReleaseVersions" && prerelease.dig("attributes", "version") == version_string && prerelease.dig("attributes", "platform") == "IOS"
    raise Error, "ASC build processing rejected" if %w[INVALID FAILED].include?(a["processingState"])
    if eligible
      raise Error, "ASC build is not processed/eligible/nonexpired" unless a["processingState"] == "VALID" &&
        a["buildAudienceType"] == "APP_STORE_ELIGIBLE" && a["expired"] == false && Time.iso8601(a.fetch("expirationDate")) > now
    end
    build
  rescue ArgumentError, KeyError, TypeError
    raise Error, "Incomplete ASC build evidence"
  end

  def wait_for_build(app_id, number, version_string:, timeout_seconds: 2700, interval: 30, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, pause: ->(s) { sleep s })
    deadline = clock.call + timeout_seconds
    loop do
      build = find_build(app_id, number, version_string: version_string)
      if build && build.dig("attributes", "processingState") == "VALID"
        return read_build(build.fetch("id"), app_id: app_id, number: number, version_string: version_string)
      end
      raise Error, "ASC processing deadline exceeded" if clock.call >= deadline
      pause.call(interval)
    end
  end
end

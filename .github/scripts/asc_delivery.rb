#!/usr/bin/env ruby
# frozen_string_literal: true

# The only mutation entry point. Authority is obtained from the C-owned Python
# gate and authenticated GitHub origin, never an operator's local JSON file.
require "open3"
require "tmpdir"
require "tempfile"
require "timeout"
require "digest"
require_relative "asc_api"
require_relative "asc_next_build"

module IOSDelivery
  module_function

  def verified_context
    helper = File.expand_path("../../ops/ci/ios_artifact.py", __dir__)
    output, _error, status = Open3.capture3("python3", helper, "context", "--repo", ENV.fetch("CONTROL_REPO", "control"))
    raise ASC::Error, "Delivery authorization/provenance rejected" unless status.success? && output.bytesize <= ASC::MAX_BODY
    JSON.parse(output)
  rescue JSON::ParserError
    raise ASC::Error, "Malformed delivery authorization"
  end

  def boolean(name, default)
    value = ENV.fetch(name, default.to_s)
    raise ASC::Error, "Invalid boolean option" unless %w[true false].include?(value)
    value == "true"
  end

  # Restrict methods, resources, relationship IDs and writable attributes as well
  # as the outer gate. GET responses establish app-scoped child identities.
  class Session
    def initialize(context, allow_cancel: false)
      @context = context
      @app = ASC.identifier(context.fetch("app_id"))
      @version = context.fetch("source").fetch("version")
      @build = context.dig("origin", "asc", "build_id")
      @target = context.fetch("authorization").fetch("target")
      @allow_cancel = allow_cancel
      @versions = []; @locales = []; @submissions = []; @beta_locales = []
    end

    def observe(method, path, response)
      uri = URI(path); base = uri.path
      data = response["data"]
      rows = data.is_a?(Array) ? data : data.is_a?(Hash) ? [data] : []
      params = URI.decode_www_form(uri.query.to_s).to_h
      destination =
        if (base == "/v1/apps/#{@app}/appStoreVersions") || (method == :post && base == "/v1/appStoreVersions")
          @versions
        elsif base.match?(%r{\A/v1/appStoreVersions/([^/]+)/appStoreVersionLocalizations\z}) && @versions.include?(base.split("/")[3]) || method == :post && base == "/v1/appStoreVersionLocalizations"
          @locales
        elsif base == "/v1/reviewSubmissions" && (method == :post || params["filter[app]"] == @app)
          @submissions
        elsif base == "/v1/builds/#{@build}/betaBuildLocalizations" || method == :post && base == "/v1/betaBuildLocalizations"
          @beta_locales
        end
      if destination.equal?(@versions)
        raise ASC::Error, "App Store version has wrong platform" unless rows.all? { |row| row.dig("attributes", "platform") == "IOS" }
      end
      rows.each { |row| destination << ASC.identifier(row.fetch("id")) } if destination
    end

    def call(method, path, body)
      raise ASC::Error, "Verification-only prohibits ASC writes" if @context.fetch("verification_only")
      raise ASC::Error, "ASC mutation method not permitted" unless %i[post patch].include?(method)
      b = JSON.parse(JSON.generate(body)); data = b["data"]
      raise ASC::Error, "Unexpected ASC mutation envelope" unless b.keys == ["data"]
      allowed = false
      if @target == "ios-upload"
        if method == :patch && path.match?(%r{\A/v1/betaBuildLocalizations/([^/]+)\z}) && @beta_locales.include?(path.split("/").last)
          allowed = data && data["type"] == "betaBuildLocalizations" && data["id"] == path.split("/").last && data.fetch("attributes").keys == ["whatsNew"] && (data.keys - %w[type id attributes]).empty?
        elsif method == :post && path == "/v1/betaBuildLocalizations"
          allowed = data && data["type"] == "betaBuildLocalizations" && data.dig("relationships", "build", "data") == { "type" => "builds", "id" => @build } && data.fetch("attributes").keys.sort == %w[locale whatsNew] && (data.keys - %w[type attributes relationships]).empty? && data["relationships"].keys == ["build"]
        end
      elsif path.match?(%r{\A/v1/appStoreVersions/([^/]+)/relationships/build\z})
        id = path.split("/")[3]
        allowed = @target == "ios-production" && method == :patch && @versions.include?(id) &&
                  (data.nil? || data == { "type" => "builds", "id" => @build })
      elsif path == "/v1/appStoreVersions" && method == :post
        allowed = @target == "ios-production" && data && data["type"] == "appStoreVersions" &&
                  data.dig("relationships", "app", "data") == { "type" => "apps", "id" => @app } &&
                  data["relationships"].keys == ["app"] && data.fetch("attributes").keys.sort == %w[platform releaseType versionString] &&
                  data.dig("attributes", "platform") == "IOS" && data.dig("attributes", "versionString") == @version &&
                  (data.keys - %w[type attributes relationships]).empty?
      elsif path.match?(%r{\A/v1/appStoreVersions/([^/]+)\z}) && method == :patch
        id = path.split("/").last
        allowed = @target == "ios-production" && @versions.include?(id) && data && data["id"] == id &&
                  data["type"] == "appStoreVersions" && data.fetch("attributes").keys.sort == %w[releaseType versionString] &&
                  data.dig("attributes", "versionString") == @version && data.keys.sort == %w[attributes id type]
      elsif path.match?(%r{\A/v1/appStoreVersionLocalizations/([^/]+)\z}) && method == :patch
        id = path.split("/").last
        allowed = @locales.include?(id) && data && data["type"] == "appStoreVersionLocalizations" && data["id"] == id &&
                  data.fetch("attributes").keys == ["whatsNew"] && data.keys.sort == %w[attributes id type]
      elsif path == "/v1/appStoreVersionLocalizations" && method == :post
        allowed = data && data["type"] == "appStoreVersionLocalizations" && @versions.include?(data.dig("relationships", "appStoreVersion", "data", "id")) &&
                  data.dig("relationships", "appStoreVersion", "data", "type") == "appStoreVersions" && data["relationships"].keys == ["appStoreVersion"] &&
                  data.fetch("attributes").keys.sort == %w[locale whatsNew] && data.keys.sort == %w[attributes relationships type]
      elsif path == "/v1/reviewSubmissions" && method == :post
        allowed = data && data["type"] == "reviewSubmissions" && data["attributes"] == { "platform" => "IOS" } &&
                  data["relationships"] == { "app" => { "data" => { "type" => "apps", "id" => @app } } } && data.keys.sort == %w[attributes relationships type]
      elsif path == "/v1/reviewSubmissionItems" && method == :post
        rel = data && data["relationships"]
        allowed = data && data["type"] == "reviewSubmissionItems" && rel && rel.keys.sort == %w[appStoreVersion reviewSubmission] &&
                  @versions.include?(rel.dig("appStoreVersion", "data", "id")) && rel.dig("appStoreVersion", "data", "type") == "appStoreVersions" &&
                  @submissions.include?(rel.dig("reviewSubmission", "data", "id")) && rel.dig("reviewSubmission", "data", "type") == "reviewSubmissions" && data.keys.sort == %w[relationships type]
      elsif path.match?(%r{\A/v1/reviewSubmissions/([^/]+)\z}) && method == :patch
        id = path.split("/").last
        attrs = data && data["attributes"]
        allowed = @submissions.include?(id) && data && data["type"] == "reviewSubmissions" && data["id"] == id &&
                  (attrs == { "submitted" => true } || @allow_cancel && attrs == { "canceled" => true }) && data.keys.sort == %w[attributes id type]
      end
      raise ASC::Error, "ASC resource/relationship/attribute outside verified release scope" unless allowed
    rescue KeyError, TypeError, NoMethodError
      raise ASC::Error, "Malformed scoped ASC write"
    end
  end

  def close_owned_group(pid)
    begin
      Process.kill("-KILL", pid)
    rescue Errno::ESRCH, Errno::EPERM
      # A terminating group can briefly be unobservable to this uid. EPERM
      # never proves cleanup: the bounded probe below must reach ESRCH.
    ensure
      begin
        Timeout.timeout(5) { Process.wait(pid) }
      rescue Errno::ECHILD
      rescue Timeout::Error
        raise ASC::Error, "Owned Apple transport parent did not stop"
      end
    end
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      begin
        Process.kill(0, -pid)
      rescue Errno::ESRCH
        break
      rescue Errno::EPERM
      end
      raise ASC::Error, "Owned Apple transport process group did not stop" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.01
    end
  end

  def finite_command(args, env = {})
    # No command-string interpolation. Never print raw altool output (even on
    # success); upload UUIDs, URLs, signing diagnostics and stderr are not proof.
    Tempfile.create("ios-transport-output-") do |output|
      pid = Process.spawn(env, *args, out: output, err: output, pgroup: true)
      begin
        _pid, status = Timeout.timeout(1800) { Process.wait2(pid) }
        raise ASC::Error, "Apple binary transport failed; reconcile upload before retry" unless status.success? && output.size <= 16 * 1024 * 1024
      rescue Timeout::Error
        raise ASC::Error, "Apple binary transport timed out; reconcile upload before retry"
      ensure
        close_owned_group(pid)
      end
    end
  end

  def inspected_bytes(path, binary)
    bytes = File.binread(path, 512 * 1024 * 1024 + 1)
    raise ASC::Error, "IPA bytes changed after inspection; reconcile origin before retry" unless
      bytes.bytesize == binary.fetch("bytes") && Digest::SHA256.hexdigest(bytes) == binary.fetch("sha256")
    bytes
  rescue SystemCallError, KeyError, TypeError
    raise ASC::Error, "Inspected IPA bytes unavailable"
  end

  def with_upload_key
    id = ASC.identifier(ASC.require_env("ASC_KEY_ID"))
    Dir.mktmpdir("ios-upload-key-", ENV["RUNNER_TEMP"]) do |dir|
      File.chmod(0o700, dir)
      path = File.join(dir, "AuthKey_#{id}.p8")
      File.write(path, ASC.require_env("DELIVERY_ASC_API_KEY_P8"), mode: "w", perm: 0o600)
      yield({ "API_PRIVATE_KEYS_DIR" => dir })
    end
  end

  def processed_receipt(build, context, number)
    a = build.fetch("attributes")
    { "app_id" => context.fetch("app_id"), "build_id" => build.fetch("id"),
      "bundle" => context.fetch("source").fetch("bundle"), "version" => context.fetch("source").fetch("version"),
      "platform" => "IOS", "build" => number, "processing_state" => a.fetch("processingState"),
      "audience" => a.fetch("buildAudienceType"), "expired" => a.fetch("expired"),
      "expiration" => a.fetch("expirationDate"), "uploaded_at" => a.fetch("uploadedDate") }
  end

  def beta_notes(context, receipt, notes)
    id = ASC.identifier(receipt.fetch("build_id"))
    upload_context = context.merge("origin" => { "asc" => receipt })
    ASC.with_write_authority(Session.new(upload_context)) do
      locales = ASC.pages("/v1/builds/#{id}/betaBuildLocalizations", { "limit" => "200" })
      if locales.empty?
        created = ASC.post("/v1/betaBuildLocalizations", { data: { type: "betaBuildLocalizations",
          attributes: { locale: "en-US", whatsNew: notes }, relationships: { build: { data: { type: "builds", id: id } } } } }).fetch("data")
        locales = [created]
      else
        locales.each do |loc|
          ASC.patch("/v1/betaBuildLocalizations/#{ASC.identifier(loc.fetch('id'))}", {
            data: { type: "betaBuildLocalizations", id: loc.fetch("id"), attributes: { whatsNew: notes } }
          })
        end
      end
      locales.each do |loc|
        readback = ASC.get("/v1/betaBuildLocalizations/#{loc.fetch('id')}").fetch("data")
        raise ASC::Error, "TestFlight notes readback mismatch" unless readback.dig("attributes", "whatsNew") == notes
      end
    end
  end

  def run(command, verifier: method(:verified_context), runner: method(:finite_command))
    raise ASC::Error, "Invalid delivery command" unless %w[prepare upload promote notes].include?(command)
    context = verifier.call
    target = { "prepare" => "ios-upload", "upload" => "ios-upload", "promote" => "ios-production", "notes" => "ios-notes" }.fetch(command)
    raise ASC::Error, "Delivery command/target mismatch" unless context.dig("authorization", "target") == target
    source = context.fetch("source"); app_id = context.fetch("app_id")
    app = ASC.find_app(source.fetch("bundle"))
    raise ASC::Error, "Current ASC app/policy mismatch" unless app.fetch("id") == app_id
    raise ASC::Error, "Invalid release type" unless %w[AFTER_APPROVAL MANUAL].include?(ENV.fetch("RELEASE_TYPE", "AFTER_APPROVAL"))
    allow_cancel = boolean("ALLOW_CANCEL", false); boolean("SUBMIT_FOR_REVIEW", true); boolean("RESUBMIT", true)
    notes = ENV.fetch("RELEASE_NOTES", "")
    raise ASC::Error, "Invalid release notes" if notes.bytesize > 16_000 || notes.include?("\0")
    if command == "prepare"
      number = context.fetch("verification_only") ? "" : next_build_number(ASC.all_builds(app_id), ENV["REQUESTED_BUILD"])
      if ENV["GITHUB_OUTPUT"]
        File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |f| f.puts "version=#{source.fetch('version')}\nbuild=#{number}" }
      end
      return { "version" => source.fetch("version"), "build" => number }
    end
    if target == "ios-upload"
      return { "verified" => true, "writes" => 0 } if context.fetch("verification_only")
      number = ASC.build_number(ASC.require_env("BUILD_NUMBER"))
      raise ASC::Error, "Upload build already exists; never retry blindly" if ASC.find_build(app_id, number, version_string: source.fetch("version"))
      path = File.expand_path(ASC.require_env("IPA_PATH"))
      helper = File.expand_path("../../ops/ci/ios_artifact.py", __dir__)
      out, _err, status = Open3.capture3("python3", helper, "inspect", "--repo", ENV.fetch("CONTROL_REPO", "control"))
      raise ASC::Error, "IPA inspection/reauthorization failed" unless status.success?
      begin
        binary = JSON.parse(out)
      rescue JSON::ParserError
        raise ASC::Error, "Malformed IPA inspection receipt"
      end
      expected_hash = ENV["IPA_SHA256"]
      raise ASC::Error, "IPA action/inspection identity mismatch" unless binary.is_a?(Hash) &&
        binary.keys.sort == %w[build bundle bytes platform sha256 version] &&
        expected_hash&.match?(%r{\A[0-9a-f]{64}\z}) && binary["sha256"] == expected_hash &&
        binary["bundle"] == source.fetch("bundle") && binary["version"] == source.fetch("version") &&
        binary["build"] == number && binary["platform"] == "IOS" &&
        binary["bytes"].is_a?(Integer) && binary["bytes"].between?(1, 512 * 1024 * 1024)
      payload = inspected_bytes(path, binary)
      with_upload_key do |key_env|
        frozen = File.join(key_env.fetch("API_PRIVATE_KEYS_DIR"), "candidate.ipa")
        File.open(frozen, File::WRONLY | File::CREAT | File::EXCL, 0o400) { |file| file.write(payload) }
        common = ["--type", "ios", "-f", frozen, "--apiKey", ASC.require_env("ASC_KEY_ID"), "--apiIssuer", ASC.require_env("ASC_ISSUER_ID")]
        runner.call(["xcrun", "altool", "--validate-app", *common], key_env)
        inspected_bytes(frozen, binary)
        inspected_bytes(path, binary)
        runner.call(["xcrun", "altool", "--upload-app", *common], key_env) # Exactly one attempt, no UUID shortcut.
        inspected_bytes(frozen, binary)
      end
      build = ASC.wait_for_build(app_id, number, version_string: source.fetch("version"))
      inspected_bytes(path, binary)
      # This is a local upload witness, not an ASC API byte-attestation field.
      receipt = processed_receipt(build, context, number).merge("upload_ipa_sha256" => binary.fetch("sha256"))
      unless notes.strip.empty?
        raise ASC::Error, "Upload authority changed before beta notes" unless verifier.call == context
        beta_notes(context, receipt, notes)
      end
      File.write(ASC.require_env("ASC_RECEIPT"), JSON.generate(receipt) + "\n", mode: "w", perm: 0o600)
      return receipt
    end
    proven = context.fetch("origin").fetch("asc")
    ASC.read_build(proven.fetch("build_id"), app_id: app_id, number: proven.fetch("build"), version_string: source.fetch("version"))
    ENV["BUNDLE_ID"] = source.fetch("bundle"); ENV["VERSION_STRING"] = source.fetch("version"); ENV["BUILD_NUMBER"] = proven.fetch("build")
    require_relative "asc_release"
    require_relative "asc_update_notes"
    if context.fetch("verification_only")
      v = ASCNotes.version(app_id, source.fetch("version"))
      ASCNotes.attached!(v.fetch("id"), proven.fetch("build_id"))
      return { "verified" => true, "writes" => 0 }
    end
    refresh = lambda do
      current = verifier.call
      raise ASC::Error, "Delivery authority changed during operation" unless current == context
      ASC.read_build(proven.fetch("build_id"), app_id: app_id, number: proven.fetch("build"), version_string: source.fetch("version"))
    end
    refresh.call
    session = Session.new(context, allow_cancel: allow_cancel)
    ASC.with_write_authority(session) do
      if command == "promote"
        release(context, submit: boolean("SUBMIT_FOR_REVIEW", true), notes: notes)
      else
        raise ASC::Error, "Notes text is required" if notes.strip.empty?
        ASCNotes.run(context, notes: notes, allow_cancel: allow_cancel, resubmit: boolean("RESUBMIT", true), reauthorize: refresh)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    IOSDelivery.run(ARGV.fetch(0))
    puts "iOS delivery operation verified"
  rescue StandardError
    warn "iOS delivery rejected: verify authority, provenance, exact build and state; reconcile any prior write before retry"
    exit 1
  end
end

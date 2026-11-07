# frozen_string_literal: true
ENV["BUNDLE_ID"] = "com.example.app"
ENV["VERSION_STRING"] = "1.4.0"
ENV["BUILD_NUMBER"] = "25"
ENV["RELEASE_TYPE"] = "AFTER_APPROVAL"
ENV["DELIVERY_ASC_API_KEY_P8"] = "INERT_P8_SENTINEL"
ENV["ASC_KEY_ID"] = "INERTKEY"
ENV["ASC_ISSUER_ID"] = "INERTISSUER"
require "minitest/autorun"
require "stringio"
require "digest"
require_relative "asc_delivery"
require_relative "asc_release"
require_relative "asc_update_notes"

# Every external request crosses the stubbed http_request seam. Any accidental
# real socket/HTTP use aborts the test, including code added in a future helper.
module Net
  class HTTP
    def self.start(*)
      raise "NETWORK FORBIDDEN IN OFFLINE ASC TESTS"
    end
  end
end

class IOSASCTests < Minitest::Test
  def setup
    @calls = []; @locale = "en-US"; @state = "PREPARE_FOR_SUBMISSION"; @attached = "build-25"; @text = "old"
    @build_state = "VALID"; @expired = false; @audience = "APP_STORE_ELIGIBLE"
    @app = "app-1"; @version_platform = "IOS"; @platform = "IOS"; @version = "1.4.0"; @number = "25"
    @versions = true; @submission_state = nil; @items = false; @uploaded = true
    @reauth = 0; @wrong_readback = false
    ENV["ALLOW_CANCEL"] = "false"; ENV["RESUBMIT"] = "true"; ENV["SUBMIT_FOR_REVIEW"] = "false"; ENV["RELEASE_NOTES"] = "new notes"
  end

  def context(target = "ios-production", verify: false)
    { "authorization" => { "target" => target }, "app_id" => "app-1", "verification_only" => verify,
      "source" => { "bundle" => "com.example.app", "version" => "1.4.0" },
      "origin" => { "asc" => { "app_id" => "app-1", "build_id" => "build-25", "build" => "25", "version" => "1.4.0" } } }
  end

  def resource(type, id, attrs = {}, rel = {})
    { "type" => type, "id" => id, "attributes" => attrs, "relationships" => rel }
  end

  def exact_build
    resource("builds", "build-25", { "version" => @number, "processingState" => @build_state, "expired" => @expired,
      "buildAudienceType" => @audience, "expirationDate" => "2099-01-01T00:00:00Z", "uploadedDate" => "2026-11-05T00:00:00Z" })
  end

  def version_resource
    resource("appStoreVersions", "version-140", { "versionString" => "1.4.0", "appStoreState" => @state, "platform" => @version_platform })
  end

  def api(method, path, body)
    parsed = URI(path); base = parsed.path
    b = body && JSON.parse(JSON.generate(body)); @calls << [method, base, b]
    data = case [method, base]
    when [:get, "/v1/apps"] then [resource("apps", "app-1", { "bundleId" => "com.example.app" })]
    when [:get, "/v1/builds"] then @uploaded ? [exact_build] : []
    when [:get, "/v1/builds/build-25"] then exact_build
    when [:get, "/v1/builds/build-25/app"] then resource("apps", @app)
    when [:get, "/v1/builds/build-25/preReleaseVersion"] then resource("preReleaseVersions", "pre-1", { "version" => @version, "platform" => @platform })
    when [:get, "/v1/apps/app-1/appStoreVersions"] then @versions ? [version_resource] : []
    when [:get, "/v1/appStoreVersions/version-140"] then version_resource
    when [:get, "/v1/appStoreVersions/version-140/relationships/build"] then { "type" => "builds", "id" => @wrong_readback ? "wrong-build" : @attached }
    when [:patch, "/v1/appStoreVersions/version-140/relationships/build"]
      @attached = b.dig("data", "id"); nil
    when [:patch, "/v1/appStoreVersions/version-140"] then @state = "PREPARE_FOR_SUBMISSION"; version_resource
    when [:post, "/v1/appStoreVersions"] then @versions = true; version_resource
    when [:get, "/v1/appStoreVersions/version-140/appStoreVersionLocalizations"] then [resource("appStoreVersionLocalizations", "loc-1", { "locale" => @locale, "whatsNew" => @text })]
    when [:patch, "/v1/appStoreVersionLocalizations/loc-1"] then @text = b.dig("data", "attributes", "whatsNew"); resource("appStoreVersionLocalizations", "loc-1")
    when [:get, "/v1/appStoreVersionLocalizations/loc-1"] then resource("appStoreVersionLocalizations", "loc-1", { "whatsNew" => @text })
    when [:get, "/v1/builds/build-25/betaBuildLocalizations"] then [resource("betaBuildLocalizations", "beta-1", { "locale" => @locale, "whatsNew" => @text })]
    when [:patch, "/v1/betaBuildLocalizations/beta-1"] then @text = b.dig("data", "attributes", "whatsNew"); resource("betaBuildLocalizations", "beta-1")
    when [:get, "/v1/betaBuildLocalizations/beta-1"] then resource("betaBuildLocalizations", "beta-1", { "whatsNew" => @text })
    when [:get, "/v1/reviewSubmissions"] then @submission_state ? [resource("reviewSubmissions", "sub-1", { "state" => @submission_state, "platform" => "IOS" })] : []
    when [:post, "/v1/reviewSubmissions"] then @submission_state = "READY_FOR_REVIEW"; resource("reviewSubmissions", "sub-1")
    when [:get, "/v1/reviewSubmissions/sub-1/items"] then @items ? [resource("reviewSubmissionItems", "item-1", {}, { "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => "version-140" } } })] : []
    when [:post, "/v1/reviewSubmissionItems"] then @items = true; resource("reviewSubmissionItems", "item-1")
    when [:patch, "/v1/reviewSubmissions/sub-1"]
      if b.dig("data", "attributes", "canceled")
        @state = "DEVELOPER_REJECTED"; @submission_state = nil
      else
        @state = "WAITING_FOR_REVIEW"; @submission_state = "WAITING_FOR_REVIEW"
      end
      resource("reviewSubmissions", "sub-1")
    when [:get, "/v1/reviewSubmissions/sub-1"] then resource("reviewSubmissions", "sub-1", { "state" => @submission_state, "submittedDate" => "2026-11-05T00:00:00Z" })
    else flunk "Unexpected synthetic method/path: #{method} #{base}"
    end
    [200, JSON.generate({ "data" => data })]
  end

  def writes
    @calls.reject { |m,| m == :get }
  end

  def execute(command, ctx = context, &block)
    verifier = lambda { @reauth += 1; ctx }
    ASC.stub(:http_request, method(:api)) do
      Open3.stub(:capture3, ->(*) { flunk "validated promotion/verification must not invoke Git or platform subprocesses" }) do
        Process.stub(:spawn, ->(*) { flunk "validated promotion/verification must not spawn a ref writer or uploader" }) do
          IOSDelivery.run(command, verifier: verifier, runner: ->(*) { flunk "promotion/notes must not build or upload" })
          block&.call
        end
      end
    end
  end

  def test_next_number_preserves_numeric_dotted_rules_and_validates_operator_input
    rows = ->(numbers) { numbers.map { |n| { "attributes" => { "version" => n } } } }
    assert_equal "1", next_build_number([])
    assert_equal "11", next_build_number(rows.call(%w[9 10]))
    assert_equal "1.3.10", next_build_number(rows.call(%w[1.3.8 1.3.9]))
    assert_equal "12", next_build_number(rows.call(%w[10]), "12")
    ["9", "10", "$(touch PWNED)", "25\nother=evil", "1..2"].each { |n| assert_raises(ASC::Error) { next_build_number(rows.call(%w[10]), n) } }
    assert_raises(ASC::Error) { next_build_number(rows.call(["not-a-build"])) }
  end

  def test_pagination_app_uniqueness_and_hostile_links
    calls = []
    reply = lambda do |_method, path, _body|
      calls << path
      obj = calls.length == 1 ? { "data" => [resource("builds", "one")], "links" => { "next" => "https://#{ASC::HOST}/v1/builds?cursor=2" } } : { "data" => [resource("builds", "two")] }
      [200, JSON.generate(obj)]
    end
    ASC.stub(:http_request, reply) { assert_equal %w[one two], ASC.pages("/v1/builds").map { |b| b["id"] } }
    ["http://#{ASC::HOST}/v1/builds", "https://evil.test/v1/builds", "https://user:pass@#{ASC::HOST}/v1/builds", "https://#{ASC::HOST}/v1/apps"].each do |link|
      ASC.stub(:http_request, ->(*) { [200, JSON.generate({ "data" => [], "links" => { "next" => link } })] }) { assert_raises(ASC::Error) { ASC.pages("/v1/builds") } }
    end
    [[], [resource("apps", "one", { "bundleId" => "wrong" })], [resource("apps", "one"), resource("apps", "two")]].each do |apps|
      ASC.stub(:http_request, ->(*) { [200, JSON.generate({ "data" => apps })] }) { assert_raises(ASC::Error) { ASC.find_app("com.example.app") } }
    end
  end

  def test_actual_current_exact_build_eligibility_and_duplicate_numbers
    ASC.stub(:http_request, method(:api)) do
      assert_equal "build-25", ASC.read_build("build-25", app_id: "app-1", number: "25", version_string: "1.4.0")["id"]
      { app: "wrong-app", platform: "MAC_OS", version: "1.3.0", number: "24", build_state: "PROCESSING", expired: true, audience: "INTERNAL_ONLY" }.each do |key, value|
        old = instance_variable_get("@#{key}"); instance_variable_set("@#{key}", value)
        assert_raises(ASC::Error) { ASC.read_build("build-25", app_id: "app-1", number: "25", version_string: "1.4.0") }
        instance_variable_set("@#{key}", old)
      end
      %w[INVALID FAILED].each do |state|
        @build_state = state
        assert_raises(ASC::Error) { ASC.wait_for_build("app-1", "25", version_string: "1.4.0", pause: ->(*) { flunk "invalid build must fail immediately" }) }
      end
    end
    ASC.stub(:all_builds, [exact_build, exact_build.merge("id" => "another")]) { assert_raises(ASC::Error) { ASC.find_build("app-1", "25", version_string: "1.4.0") } }
  end

  def test_processing_wait_has_deadline_and_requires_positive_build_readback
    ticks = 0
    ASC.stub(:http_request, method(:api)) do
      @build_state = "PROCESSING"
      clock = -> { ticks += 1 }
      assert_raises(ASC::Error) { ASC.wait_for_build("app-1", "25", version_string: "1.4.0", timeout_seconds: 3, clock: clock, pause: ->(*) {}) }
      ticks = 0
      build = ASC.wait_for_build("app-1", "25", version_string: "1.4.0", clock: clock, pause: ->(*) { @build_state = "VALID" })
      assert_equal "build-25", build["id"]
    end
  end

  def test_mutation_guard_status_errors_and_tainted_payloads_never_escape
    %i[post patch delete].each do |verb|
      assert_raises(ASC::Error) { ASC.request(verb, "/v1/synthetic", body: {}, allow_failure: true) }
    end
    [401, 403, 429, 503].each do |code|
      out, err = capture_io do
        ASC.stub(:http_request, ->(*) { [code, 'INERT_P8_SENTINEL signed-url INERT_GH_SENTINEL'] }) do
          error = assert_raises(ASC::RequestError) { ASC.get("/v1/apps", {}, allow_failure: true) }
          assert_equal code, error.status
          refute_match(/SENTINEL|signed-url/, error.message)
        end
      end
      assert_empty out + err
    end
    ASC.stub(:http_request, ->(*) { [400, 'INERT_P8_SENTINEL'] }) { assert_nil ASC.get("/v1/apps", {}, allow_failure: true) }
    @locale = "INERT_API_TAINT\n::error::hostile"
    out, err = capture_io { execute("promote") }
    refute_match(/INERT_API_TAINT|hostile/, out + err)
  end

  def test_scoped_session_rejects_marketing_wrong_build_and_cancel_without_consent
    session = IOSDelivery::Session.new(context)
    session.observe(:get, "/v1/apps/app-1/appStoreVersions", { "data" => [version_resource] })
    session.observe(:get, "/v1/reviewSubmissions?filter%5Bapp%5D=app-1", { "data" => [resource("reviewSubmissions", "sub-1")] })
    ASC.with_write_authority(session) do
      paths = [[:patch, "/v1/appStoreVersions/version-140/relationships/build", { data: { type: "builds", id: "wrong-build" } }],
               [:patch, "/v1/appStoreVersions/wrong-version/relationships/build", { data: { type: "builds", id: "build-25" } }],
               [:patch, "/v1/reviewSubmissions/sub-1", { data: { type: "reviewSubmissions", id: "sub-1", attributes: { canceled: true } } }],
               [:post, "/v1/appScreenshotSets", { data: {} }], [:delete, "/v1/appStoreVersions/version-140", {}]]
      paths.each { |method, path, body| assert_raises(ASC::Error) { ASC.request(method, path, body: body) } }
    end
    assert_raises(ASC::Error) { ASC.patch("/v1/appStoreVersions/version-140/relationships/build", { data: nil }) }
  end

  def test_exact_promotion_and_stage_readback_never_allocate_rebuild_or_upload
    @attached = "old-build"
    execute("promote")
    assert_equal "build-25", @attached
    assert_equal "new notes", @text
    assert_equal 1, writes.count { |_, p, b| p.end_with?("/relationships/build") && b.dig("data", "id") == "build-25" }
    refute @calls.any? { |_, p,| p == "/v1/builds" }
    assert_operator @reauth, :>=, 2
    setup; @wrong_readback = true
    assert_raises(ASC::Error) { execute("promote") }
    refute writes.any? { |_, p,| p == "/v1/reviewSubmissions" }
  end

  def test_rejected_release_and_three_step_submission_are_preserved
    @state = "REJECTED"; ENV["SUBMIT_FOR_REVIEW"] = "true"
    execute("promote")
    assert writes.any? { |_, p, b| p.end_with?("/relationships/build") && b["data"].nil? }
    assert_equal "WAITING_FOR_REVIEW", @submission_state
    flow = writes.select { |_, p,| p.include?("reviewSubmission") }.map { |m, p,| [m, p] }
    assert_equal [[:post, "/v1/reviewSubmissions"], [:post, "/v1/reviewSubmissionItems"], [:patch, "/v1/reviewSubmissions/sub-1"]], flow
  end

  def test_notes_exact_attached_build_default_cancel_and_explicit_resubmit
    execute("notes", context("ios-notes"))
    assert_equal ["/v1/appStoreVersionLocalizations/loc-1"], writes.map { |_, p,| p }
    setup; @version_platform = "MAC_OS"
    assert_raises(ASC::Error) { execute("notes", context("ios-notes")) }; assert_empty writes
    setup; @attached = "wrong-build"
    assert_raises(ASC::Error) { execute("notes", context("ios-notes")) }; assert_empty writes
    setup; @state = "WAITING_FOR_REVIEW"; @submission_state = "WAITING_FOR_REVIEW"; @items = true
    assert_raises(ASC::Error) { execute("notes", context("ios-notes")) }; assert_empty writes
    ENV["ALLOW_CANCEL"] = "true"
    execute("notes", context("ios-notes"))
    assert_equal "build-25", @attached
    assert writes.any? { |_, p, b| p == "/v1/reviewSubmissions/sub-1" && b.dig("data", "attributes", "canceled") }
    assert_equal "WAITING_FOR_REVIEW", @submission_state
    assert_operator @reauth, :>=, 4
  end

  def test_verification_only_never_creates_keys_signs_uploads_tags_or_writes
    %w[promote notes upload prepare].each do |command|
      target = %w[prepare upload].include?(command) ? "ios-upload" : command == "notes" ? "ios-notes" : "ios-production"
      setup
      execute(command, context(target, verify: true))
      assert_empty writes
      refute @calls.any? { |_, p,| p == "/v1/builds" }
    end
  end

  def test_upload_once_processing_and_key_cleanup_on_failure
    Dir.mktmpdir("ios-key-fixture-") do |dir|
      old_temp = ENV["RUNNER_TEMP"]; ENV["RUNNER_TEMP"] = dir
      captured = nil
      assert_raises(ASC::Error) do
        IOSDelivery.with_upload_key do |key_env|
          captured = key_env.fetch("API_PRIVATE_KEYS_DIR")
          key = File.join(captured, "AuthKey_INERTKEY.p8")
          assert_equal 0o600, File.stat(key).mode & 0o777
          assert_equal "INERT_P8_SENTINEL", File.read(key)
          raise ASC::Error, "synthetic upload failure"
        end
      end
      refute File.exist?(captured)
      ENV["RUNNER_TEMP"] = old_temp
    end
  end
  def test_JWT_refreshes_before_expiry_using_only_inert_signing_stubs
    key = Object.new
    def key.sign(*); "INERT_DER"; end
    numbers = Struct.new(:value).new([Struct.new(:value).new(1), Struct.new(:value).new(2)])
    ASC.instance_variable_set(:@token, nil)
    ASC.instance_variable_set(:@token_expires, nil)
    OpenSSL::PKey.stub(:read, key) do
      OpenSSL::ASN1.stub(:decode, numbers) do
        token = Time.stub(:now, Time.at(1000)) { ASC.token }
        assert_equal token, Time.stub(:now, Time.at(1500)) { ASC.token }
        renewed = Time.stub(:now, Time.at(2200)) { ASC.token }
        refute_equal token, renewed
      end
    end
  ensure
    ASC.instance_variable_set(:@token, nil)
    ASC.instance_variable_set(:@token_expires, nil)
  end

  def test_real_upload_entry_point_calls_validate_upload_once_and_persists_processed_ID
    Dir.mktmpdir("ios-upload-fixture-") do |dir|
      old_env = ENV.to_h
      ENV["RUNNER_TEMP"] = dir; ENV["IPA_PATH"] = File.join(dir, "candidate.ipa"); ENV["ASC_RECEIPT"] = File.join(dir, "asc.json")
      bytes = "SYNTHETIC IPA INSPECTED BY INJECTED PYTHON SEAM"
      File.binwrite(ENV.fetch("IPA_PATH"), bytes)
      ENV["IPA_SHA256"] = Digest::SHA256.hexdigest(bytes)
      ctx = context("ios-upload"); @uploaded = false
      commands = []; status = Struct.new(:success?).new(true)
      binary = { "bundle" => "com.example.app", "version" => "1.4.0", "build" => "25", "platform" => "IOS",
                 "sha256" => ENV.fetch("IPA_SHA256"), "bytes" => bytes.bytesize }
      inspect = ->(*args) { assert_includes args, "inspect"; [JSON.generate(binary), "", status] }
      runner = lambda do |args, key_env|
        commands << args
        assert File.exist?(File.join(key_env.fetch("API_PRIVATE_KEYS_DIR"), "AuthKey_INERTKEY.p8"))
        @uploaded = true if args.include?("--upload-app")
      end
      ASC.stub(:http_request, method(:api)) do
        Open3.stub(:capture3, inspect) { IOSDelivery.run("upload", verifier: -> { ctx }, runner: runner) }
      end
      assert_equal 1, commands.count { |c| c.include?("--validate-app") }
      assert_equal 1, commands.count { |c| c.include?("--upload-app") }
      record = JSON.parse(File.read(ENV.fetch("ASC_RECEIPT")))
      assert_equal "build-25", record.fetch("build_id")
      assert_equal "VALID", record.fetch("processing_state")
      assert_equal binary.fetch("sha256"), record.fetch("upload_ipa_sha256")
      assert_empty Dir.glob(File.join(dir, "ios-upload-key-*"))
      commands.clear
      assert_raises(ASC::Error) do
        ASC.stub(:http_request, method(:api)) { IOSDelivery.run("upload", verifier: -> { ctx }, runner: runner) }
      end
      assert_empty commands # Existing build cannot cause another upload.
    ensure
      ENV.replace(old_env) if old_env
    end
  end

  def test_expiry_guard_removal_is_detected_against_otherwise_healthy_build
    source = File.read(File.join(__dir__, "asc_api.rb"))
    guard = 'a["expired"] == false && '
    assert_equal 1, source.scan(guard).length
    sandbox = Module.new
    sandbox.module_eval(source.sub(guard, ""), "synthetic-asc-expiry-mutant.rb")
    mutant = sandbox.const_get(:ASC)
    @expired = true
    ASC.stub(:http_request, method(:api)) { assert_raises(ASC::Error) { ASC.read_build("build-25", app_id: "app-1", number: "25", version_string: "1.4.0") } }
    mutant.stub(:http_request, method(:api)) do
      assert_raises(Minitest::Assertion) do
        assert_raises(mutant.const_get(:Error)) { mutant.read_build("build-25", app_id: "app-1", number: "25", version_string: "1.4.0") }
      end
    end
    if ENV["CONTROL_RUBY_REPORT"]
      File.write(ENV.fetch("CONTROL_RUBY_REPORT"), JSON.generate({ guard: guard, original_source_sha256: Digest::SHA256.hexdigest(source), mutant_source_sha256: Digest::SHA256.hexdigest(source.sub(guard, "")), fixture_sha256: Digest::SHA256.hexdigest(JSON.generate(exact_build)), original: "REJECT", mutant: "ACCEPT", negative_assertion: "FAILED AS EXPECTED / caught by control" }) + "\n")
    end
  end

  def test_finite_command_failure_never_logs_tainted_output
    out, err = capture_io do
      assert_raises(ASC::Error) { IOSDelivery.finite_command([RbConfig.ruby, "-e", 'puts "INERT_P8_SENTINEL signed-url"; exit 1']) }
    end
    assert_empty out + err
  end

  def with_upload_fixture
    Dir.mktmpdir("ios-continuity-fixture-") do |dir|
      before = ENV.to_h
      bytes = "SYNTHETIC IPA A WITH FIXED METADATA"
      ENV["RUNNER_TEMP"] = dir
      ENV["IPA_PATH"] = File.join(dir, "candidate.ipa")
      ENV["ASC_RECEIPT"] = File.join(dir, "processed.json")
      ENV["IPA_SHA256"] = Digest::SHA256.hexdigest(bytes)
      File.binwrite(ENV.fetch("IPA_PATH"), bytes)
      binary = { "bundle" => "com.example.app", "version" => "1.4.0", "build" => "25", "platform" => "IOS",
                 "sha256" => ENV.fetch("IPA_SHA256"), "bytes" => bytes.bytesize }
      status = Struct.new(:success?).new(true)
      inspect = ->(*) { [JSON.generate(binary), "", status] }
      @uploaded = false
      yield dir, bytes, binary, inspect
    ensure
      ENV.replace(before) if before
    end
  end

  def test_upload_to_receipt_substitution_is_rejected_after_otherwise_healthy_transport
    [false, true].each do |tamper|
      with_upload_fixture do |dir, bytes, binary, inspect|
        commands = []
        runner = lambda do |args, _key_env|
          commands << args
          selected = args.fetch(args.index("-f") + 1)
          assert_equal bytes, File.binread(selected), "actual transport input differs from inspected bytes"
          if args.include?("--upload-app")
            @uploaded = true
            File.binwrite(ENV.fetch("IPA_PATH"), "SYNTHETIC IPA B WITH SAME METADATA") if tamper
          end
        end
        ASC.stub(:http_request, method(:api)) do
          Open3.stub(:capture3, inspect) do
            if tamper
              assert_raises(ASC::Error) { IOSDelivery.run("upload", verifier: -> { context("ios-upload") }, runner: runner) }
              refute File.exist?(ENV.fetch("ASC_RECEIPT")), "mismatched provenance must not be persisted"
            else
              IOSDelivery.run("upload", verifier: -> { context("ios-upload") }, runner: runner)
              assert_equal "build-25", JSON.parse(File.read(ENV.fetch("ASC_RECEIPT"))).fetch("build_id")
            end
          end
        end
        assert_equal 1, commands.count { |c| c.include?("--validate-app") }
        assert_equal 1, commands.count { |c| c.include?("--upload-app") }
        assert_empty Dir.glob(File.join(dir, "ios-upload-key-*"))
      end
    end
  end

  def test_action_hash_mismatch_is_rejected_before_key_setup_or_transport
    with_upload_fixture do |dir, _bytes, _binary, inspect|
      ENV["IPA_SHA256"] = "0" * 64
      commands = []
      ASC.stub(:http_request, method(:api)) do
        Open3.stub(:capture3, inspect) do
          assert_raises(ASC::Error) do
            IOSDelivery.run("upload", verifier: -> { context("ios-upload") }, runner: ->(args, *) { commands << args; @uploaded = true })
          end
        end
      end
      assert_empty commands
      assert_empty Dir.glob(File.join(dir, "ios-upload-key-*"))
    end
  end

  def test_finite_command_closes_owned_descendants_for_both_parent_results
    Dir.mktmpdir("ios-owned-process-") do |dir|
      child_code = 'require "json"; File.write(ARGV[0], JSON.generate({pid: Process.pid, pgid: Process.getpgrp})); sleep 30'
      parent_code = 'require "rbconfig"; Process.spawn(RbConfig.ruby, "-e", ARGV[2], ARGV[0]); deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3; until File.exist?(ARGV[0]); raise "child marker missing" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline; sleep 0.01; end; exit Integer(ARGV[1])'
      [0, 1].each do |code|
        marker = File.join(dir, "process-#{code}.json")
        begin
          args = [RbConfig.ruby, "-e", parent_code, marker, code.to_s, child_code]
          if code.zero?
            IOSDelivery.finite_command(args)
          else
            assert_raises(ASC::Error) { IOSDelivery.finite_command(args) }
          end
          assert File.file?(marker), "actual child must run before parent exits"
          owned = JSON.parse(File.read(marker))
          alive = begin Process.kill(0, owned.fetch("pid")); true; rescue Errno::ESRCH; false; end
          refute alive, "owned descendant survives returned command"
        ensure
          if File.file?(marker)
            owned = JSON.parse(File.read(marker))
            IOSDelivery.close_owned_group(owned.fetch("pgid"))
            if ENV["CASE_REPORT"]
              File.open(File.join(File.dirname(ENV.fetch("CASE_REPORT")), "ios-owned-ruby-processes.jsonl"), "a") do |log|
                log.puts JSON.generate(owned.merge("parent_exit" => code, "group_absent_after_cleanup" => true))
              end
            end
          end
        end
      end
    end
    # A persistent permission error is never converted into an absent-group
    # success. The fake clock reaches the same bounded error without sleeping.
    tick = 0
    Process.stub(:kill, ->(*) { raise Errno::EPERM }) do
      Process.stub(:wait, ->(*) { raise Errno::ECHILD }) do
        Process.stub(:clock_gettime, ->(*) { tick += 6 }) do
          assert_raises(ASC::Error) { IOSDelivery.close_owned_group(123456) }
        end
      end
    end
  end

end

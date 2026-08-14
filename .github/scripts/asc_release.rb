#!/usr/bin/env ruby
# frozen_string_literal: true

# Promote an uploaded build to an App Store production release.
#
# SCOPE — this script deliberately touches only the app *package*:
#   * creates (or reuses) the App Store version for VERSION_STRING
#   * attaches the processed build to it
#   * optionally sets the "What's New" text
#   * submits the version to App Review
#
# It NEVER touches screenshots, app previews, the description, keywords,
# promotional text, the icon, or any other marketing asset. Those stay
# managed by hand in App Store Connect. There is no code path here that
# writes to appScreenshotSets, appPreviewSets, or appInfoLocalizations.
#
# Required env:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH  (see asc_api.rb)
#   BUNDLE_ID       e.g. com.checksinmyhead-vng.app
#   VERSION_STRING  marketing version, e.g. 1.3.1
#   BUILD_NUMBER    CFBundleVersion of the uploaded build, e.g. 11
# Optional env:
#   RELEASE_NOTES   "What's New" text; skipped entirely when blank
#   RELEASE_TYPE    AFTER_APPROVAL (default) | MANUAL | SCHEDULED
#   SUBMIT_FOR_REVIEW  "true" (default) | "false" to stop before submitting

require_relative "asc_api"

BUNDLE_ID = ASC.require_env("BUNDLE_ID")
VERSION_STRING = ASC.require_env("VERSION_STRING")
BUILD_NUMBER = ASC.require_env("BUILD_NUMBER")
RELEASE_NOTES = ENV["RELEASE_NOTES"].to_s.strip
RELEASE_TYPE = ENV.fetch("RELEASE_TYPE", "AFTER_APPROVAL")
SUBMIT = ENV.fetch("SUBMIT_FOR_REVIEW", "true") == "true"
DEFAULT_LOCALE = ENV.fetch("DEFAULT_LOCALE", "en-US")

# Versions in these states can still be edited and resubmitted. Anything else
# (WAITING_FOR_REVIEW, IN_REVIEW, READY_FOR_SALE, ...) must not be touched.
EDITABLE_STATES = %w[
  PREPARE_FOR_SUBMISSION
  DEVELOPER_REJECTED
  REJECTED
  METADATA_REJECTED
  INVALID_BINARY
].freeze

def find_editable_version(app_id, version_string)
  response = ASC.get("/v1/apps/#{app_id}/appStoreVersions", {
    "filter[platform]" => "IOS",
    "fields[appStoreVersions]" => "versionString,appStoreState,appVersionState,releaseType",
    "limit" => "50"
  })

  versions = response.fetch("data", [])

  exact = versions.find { |v| v.dig("attributes", "versionString") == version_string }
  if exact
    state = exact.dig("attributes", "appStoreState") || exact.dig("attributes", "appVersionState")
    unless EDITABLE_STATES.include?(state)
      raise ASC::Error, "Version #{version_string} already exists in state #{state} and cannot be edited. " \
                        "Resolve it in App Store Connect, or tag a new version."
    end
    puts "Reusing existing editable version #{version_string} (state #{state})"
    return exact
  end

  # Guard against two live edit sessions: if a *different* version is already
  # open for editing, creating another one will be rejected by Apple anyway.
  open = versions.find do |v|
    state = v.dig("attributes", "appStoreState") || v.dig("attributes", "appVersionState")
    EDITABLE_STATES.include?(state)
  end
  if open
    open_state = open.dig("attributes", "appStoreState") || open.dig("attributes", "appVersionState")
    if %w[DEVELOPER_REJECTED REJECTED METADATA_REJECTED INVALID_BINARY].include?(open_state)
      puts "Leaving rejected App Store version #{open.dig('attributes', 'versionString')} in place " \
           "(state #{open_state}); attempting to create #{version_string}"
      return nil
    end

    raise ASC::Error, "Version #{open.dig('attributes', 'versionString')} is already open for editing " \
                      "(state #{open.dig('attributes', 'appStoreState')}). Release or delete it before " \
                      "creating #{version_string}."
  end

  nil
end

def create_version(app_id, version_string)
  puts "Creating App Store version #{version_string} (releaseType #{RELEASE_TYPE})"
  body = {
    data: {
      type: "appStoreVersions",
      attributes: {
        platform: "IOS",
        versionString: version_string,
        releaseType: RELEASE_TYPE
      },
      relationships: {
        app: { data: { type: "apps", id: app_id } }
      }
    }
  }

  ASC.post("/v1/appStoreVersions", body).fetch("data")
end

def attach_build(version_id, build_id)
  puts "Attaching build #{build_id} to version #{version_id}"
  ASC.patch("/v1/appStoreVersions/#{version_id}/relationships/build", {
    data: { type: "builds", id: build_id }
  })
end

# Updates whatsNew on localizations that ALREADY exist. Does not create new
# locales and does not touch any other localized field.
def update_release_notes(version_id, notes)
  response = ASC.get("/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations", {
    "fields[appStoreVersionLocalizations]" => "locale,whatsNew",
    "limit" => "50"
  })

  localizations = response.fetch("data", [])

  # A freshly created version is not always seeded with localizations, in which
  # case the notes would be silently dropped. Create one for the primary locale
  # instead. This is allow_failure on purpose: shipping the binary matters more
  # than the notes, so a metadata hiccup must never abort the release.
  if localizations.empty?
    puts "Version has no localizations; creating #{DEFAULT_LOCALE} to carry the release notes"
    created = ASC.post("/v1/appStoreVersionLocalizations", {
      data: {
        type: "appStoreVersionLocalizations",
        attributes: { locale: DEFAULT_LOCALE, whatsNew: notes },
        relationships: {
          appStoreVersion: { data: { type: "appStoreVersions", id: version_id } }
        }
      }
    }, allow_failure: true)

    warn "::warning::Could not set release notes; submitting without them." if created.nil?
    return
  end

  localizations.each do |loc|
    locale = loc.dig("attributes", "locale")
    puts "Setting What's New for #{locale}"
    ASC.patch("/v1/appStoreVersionLocalizations/#{loc.fetch('id')}", {
      data: {
        type: "appStoreVersionLocalizations",
        id: loc.fetch("id"),
        attributes: { whatsNew: notes }
      }
    })
  end
end

# Apple replaced the one-shot appStoreVersionSubmissions endpoint with a
# three-step flow: create a container, add items, then flip `submitted`.
# The order is mandatory — patching before adding items returns HTTP 422.
# Filtering by state server-side risks a 400 on an enum Apple may rename, and
# a swallowed error there would read as "no open submission" and create a
# duplicate. Fetch and filter locally instead, and let real errors raise.
def open_submission(app_id)
  # Sparse fieldsets keep the payload small, but this is the only lookup whose
  # failure would abort a release that has already uploaded a build. Fall back
  # to an unfiltered read rather than dying on a rejected fields[] parameter.
  response = ASC.get("/v1/reviewSubmissions", {
    "filter[app]" => app_id,
    "fields[reviewSubmissions]" => "state,platform,submittedDate",
    "limit" => "50"
  }, allow_failure: true)

  response ||= ASC.get("/v1/reviewSubmissions", {
    "filter[app]" => app_id,
    "limit" => "50"
  })

  response.fetch("data", []).find do |s|
    s.dig("attributes", "state") == "READY_FOR_REVIEW" &&
      s.dig("attributes", "platform") == "IOS"
  end
end

# Apple exposes the items both as a sub-resource and as a filterable
# collection. Try both so a path change on either side is not fatal.
def submission_items(submission_id)
  ASC.get("/v1/reviewSubmissions/#{submission_id}/items", {
    "include" => "appStoreVersion",
    "limit" => "50"
  }, allow_failure: true) ||
    ASC.get("/v1/reviewSubmissionItems", {
      "filter[reviewSubmission]" => submission_id,
      "include" => "appStoreVersion",
      "limit" => "50"
    }, allow_failure: true)
end

def version_attached?(items, version_id)
  return false unless items

  items.fetch("data", []).any? do |item|
    item.dig("relationships", "appStoreVersion", "data", "id") == version_id
  end
end

def submit_for_review(app_id, version_id)
  submission = open_submission(app_id)

  if submission
    puts "Reusing open review submission #{submission.fetch('id')}"
  else
    puts "Creating review submission"
    submission = ASC.post("/v1/reviewSubmissions", {
      data: {
        type: "reviewSubmissions",
        attributes: { platform: "IOS" },
        relationships: {
          app: { data: { type: "apps", id: app_id } }
        }
      }
    }).fetch("data")
  end

  submission_id = submission.fetch("id")

  if version_attached?(submission_items(submission_id), version_id)
    puts "Version already attached to submission #{submission_id}"
  else
    puts "Adding version #{version_id} to submission #{submission_id}"
    added = ASC.post("/v1/reviewSubmissionItems", {
      data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: { data: { type: "reviewSubmissions", id: submission_id } },
          appStoreVersion: { data: { type: "appStoreVersions", id: version_id } }
        }
      }
    }, allow_failure: true)

    # A failure here is ambiguous: on a re-run it usually means "already
    # attached". Re-read before deciding, so we never submit an empty container.
    if added.nil?
      unless version_attached?(submission_items(submission_id), version_id)
        raise ASC::Error, "Could not add version #{version_id} to review submission #{submission_id}, " \
                          "and it is not already attached. See the API error above."
      end
      puts "Version was already attached to submission #{submission_id}."
    end
  end

  puts "Submitting #{submission_id} to App Review"
  ASC.patch("/v1/reviewSubmissions/#{submission_id}", {
    data: {
      type: "reviewSubmissions",
      id: submission_id,
      attributes: { submitted: true }
    }
  })

  submission_id
end

app = ASC.find_app(BUNDLE_ID)
app_id = app.fetch("id")
puts "App: #{app.dig('attributes', 'name')} (#{BUNDLE_ID}) id=#{app_id}"

build = ASC.wait_for_build(app_id, BUILD_NUMBER)
build_id = build.fetch("id")
puts "Build #{BUILD_NUMBER} is VALID (id=#{build_id})"

version = find_editable_version(app_id, VERSION_STRING) || create_version(app_id, VERSION_STRING)
version_id = version.fetch("id")

attach_build(version_id, build_id)

if RELEASE_NOTES.empty?
  puts "No RELEASE_NOTES provided; leaving existing What's New untouched."
else
  update_release_notes(version_id, RELEASE_NOTES)
end

if SUBMIT
  submission_id = submit_for_review(app_id, version_id)
  puts "Submitted for review. Submission #{submission_id}, version #{VERSION_STRING}, build #{BUILD_NUMBER}."
else
  puts "SUBMIT_FOR_REVIEW=false — version #{VERSION_STRING} prepared with build #{BUILD_NUMBER} but NOT submitted."
end

if (summary = ENV["GITHUB_STEP_SUMMARY"])
  File.open(summary, "a") do |f|
    f.puts "### App Store release"
    f.puts
    f.puts "| Field | Value |"
    f.puts "| --- | --- |"
    f.puts "| Version | `#{VERSION_STRING}` |"
    f.puts "| Build | `#{BUILD_NUMBER}` |"
    f.puts "| Release type | `#{RELEASE_TYPE}` |"
    f.puts "| Submitted for review | `#{SUBMIT}` |"
    f.puts "| Screenshots / marketing images | untouched (managed manually) |"
  end
end

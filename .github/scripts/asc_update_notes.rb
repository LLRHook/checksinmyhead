#!/usr/bin/env ruby
# frozen_string_literal: true

# Update the "What's New" text on an App Store version.
#
# Scope is deliberately narrow: this touches whatsNew and nothing else. It
# never writes screenshots, previews, description, keywords, or the icon.
#
# A version that has already been submitted is locked by Apple. Editing it
# requires cancelling the review submission first, which forfeits your place
# in the review queue — so that only happens when ALLOW_CANCEL=true, and the
# script resubmits afterwards unless told not to.
#
# Required env:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
#   BUNDLE_ID, VERSION_STRING, RELEASE_NOTES
# Optional env:
#   ALLOW_CANCEL   "true" to cancel a pending submission in order to edit
#   RESUBMIT       "true" (default) to resubmit after a cancel+edit
#   DEFAULT_LOCALE default "en-US"

require_relative "asc_api"

BUNDLE_ID = ASC.require_env("BUNDLE_ID")
VERSION_STRING = ASC.require_env("VERSION_STRING")
RELEASE_NOTES = ASC.require_env("RELEASE_NOTES")
ALLOW_CANCEL = ENV.fetch("ALLOW_CANCEL", "false") == "true"
RESUBMIT = ENV.fetch("RESUBMIT", "true") == "true"
DEFAULT_LOCALE = ENV.fetch("DEFAULT_LOCALE", "en-US")

def find_version(app_id, version_string)
  response = ASC.get("/v1/apps/#{app_id}/appStoreVersions", {
    "filter[platform]" => "IOS",
    "limit" => "50"
  })

  version = response.fetch("data", []).find do |v|
    v.dig("attributes", "versionString") == version_string
  end
  raise ASC::Error, "No iOS App Store version #{version_string} found." unless version

  version
end

def localizations(version_id)
  ASC.get("/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations", {
    "limit" => "50"
  }).fetch("data", [])
end

def write_notes(version_id, notes)
  locs = localizations(version_id)

  if locs.empty?
    puts "No localizations; creating #{DEFAULT_LOCALE}"
    result = ASC.post("/v1/appStoreVersionLocalizations", {
      data: {
        type: "appStoreVersionLocalizations",
        attributes: { locale: DEFAULT_LOCALE, whatsNew: notes },
        relationships: {
          appStoreVersion: { data: { type: "appStoreVersions", id: version_id } }
        }
      }
    }, allow_failure: true)
    return !result.nil?
  end

  ok = true
  locs.each do |loc|
    locale = loc.dig("attributes", "locale")
    current = loc.dig("attributes", "whatsNew").to_s
    puts "#{locale}: current What's New begins #{current.lines.first.to_s.strip.inspect}"

    result = ASC.patch("/v1/appStoreVersionLocalizations/#{loc.fetch('id')}", {
      data: {
        type: "appStoreVersionLocalizations",
        id: loc.fetch("id"),
        attributes: { whatsNew: notes }
      }
    }, allow_failure: true)

    if result.nil?
      warn "#{locale}: update rejected"
      ok = false
    else
      puts "#{locale}: updated"
    end
  end
  ok
end

def pending_submission(app_id, version_id)
  response = ASC.get("/v1/reviewSubmissions", { "filter[app]" => app_id, "limit" => "50" },
                     allow_failure: true)
  return nil unless response

  response.fetch("data", []).find do |s|
    state = s.dig("attributes", "state")
    next false unless %w[READY_FOR_REVIEW WAITING_FOR_REVIEW].include?(state)

    items = ASC.get("/v1/reviewSubmissions/#{s.fetch('id')}/items", { "limit" => "50" },
                    allow_failure: true)
    items && items.fetch("data", []).any? do |i|
      i.dig("relationships", "appStoreVersion", "data", "id") == version_id
    end
  end
end

app = ASC.find_app(BUNDLE_ID)
app_id = app.fetch("id")
version = find_version(app_id, VERSION_STRING)
version_id = version.fetch("id")
state = version.dig("attributes", "appStoreState") || version.dig("attributes", "appVersionState")

puts "App:     #{app.dig('attributes', 'name')} (#{BUNDLE_ID})"
puts "Version: #{VERSION_STRING} id=#{version_id} state=#{state}"
puts

if write_notes(version_id, RELEASE_NOTES)
  puts "\nRelease notes updated in place. No submission changes were needed."
  exit 0
end

puts "\nApple rejected the edit, which means the version is locked by a pending submission."

unless ALLOW_CANCEL
  warn "::error::Cannot edit #{VERSION_STRING} while it is awaiting review. " \
       "Re-run with ALLOW_CANCEL=true to cancel the submission, apply the notes and resubmit. " \
       "Cancelling forfeits the current place in the review queue."
  exit 1
end

submission = pending_submission(app_id, version_id)
raise ASC::Error, "Version is locked but no pending review submission was found; resolve it in App Store Connect." unless submission

submission_id = submission.fetch("id")
puts "Cancelling review submission #{submission_id}"
ASC.patch("/v1/reviewSubmissions/#{submission_id}", {
  data: {
    type: "reviewSubmissions",
    id: submission_id,
    attributes: { canceled: true }
  }
})

# Apple needs a moment to unlock the version after a cancel.
12.times do
  sleep 10
  break if write_notes(version_id, RELEASE_NOTES)
end

raise ASC::Error, "Still could not update the notes after cancelling #{submission_id}." unless write_notes(version_id, RELEASE_NOTES)

puts "Release notes updated."

unless RESUBMIT
  puts "RESUBMIT=false — version #{VERSION_STRING} is NOT submitted. Submit it in App Store Connect when ready."
  exit 0
end

puts "Creating a fresh review submission"
new_submission = ASC.post("/v1/reviewSubmissions", {
  data: {
    type: "reviewSubmissions",
    attributes: { platform: "IOS" },
    relationships: { app: { data: { type: "apps", id: app_id } } }
  }
}).fetch("data")

ASC.post("/v1/reviewSubmissionItems", {
  data: {
    type: "reviewSubmissionItems",
    relationships: {
      reviewSubmission: { data: { type: "reviewSubmissions", id: new_submission.fetch("id") } },
      appStoreVersion: { data: { type: "appStoreVersions", id: version_id } }
    }
  }
})

ASC.patch("/v1/reviewSubmissions/#{new_submission.fetch('id')}", {
  data: {
    type: "reviewSubmissions",
    id: new_submission.fetch("id"),
    attributes: { submitted: true }
  }
})

puts "Resubmitted #{VERSION_STRING} for review as #{new_submission.fetch('id')}."

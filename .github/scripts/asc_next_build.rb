#!/usr/bin/env ruby
# frozen_string_literal: true

# Print the next CFBundleVersion to use for an upload.
#
# App Store Connect is the source of truth here, not git tags. Deriving the
# build number from tags drifts the moment an upload succeeds but the tag push
# fails (or someone uploads from a laptop), and the next run then collides with
# "The bundle version must be higher than the previously uploaded version".
#
# Required env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, BUNDLE_ID

require_relative "asc_api"

BUNDLE_ID = ASC.require_env("BUNDLE_ID")

app = ASC.find_app(BUNDLE_ID)
app_id = app.fetch("id")

response = ASC.get("/v1/builds", {
  "filter[app]" => app_id,
  "fields[builds]" => "version,uploadedDate",
  "limit" => "200",
  "sort" => "-uploadedDate"
})

builds = response.fetch("data", [])

# Build numbers are strings server-side and may be dotted ("1.3.1"). Compare
# them as version tuples so "10" sorts above "9" rather than below it.
def version_key(value)
  value.to_s.split(".").map { |part| part.to_i }
end

highest = builds
          .map { |b| b.dig("attributes", "version") }
          .compact
          .max_by { |v| version_key(v) }

next_build =
  if highest.nil?
    1
  elsif highest.include?(".")
    # Preserve a dotted scheme by bumping only the last component.
    parts = highest.split(".")
    (parts[0..-2] + [(parts[-1].to_i + 1).to_s]).join(".")
  else
    highest.to_i + 1
  end

warn "Highest build on App Store Connect: #{highest.inspect} -> next: #{next_build}"
puts next_build

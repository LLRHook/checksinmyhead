#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "asc_api"

# Preserve tuple comparison and dotted last-component increment. Input validation
# prevents malformed provider versions from silently becoming zero with to_i.
def version_key(value)
  ASC.build_number(value).split(".").map(&:to_i)
end

def next_build_number(builds, requested = nil)
  numbers = builds.map { |b| ASC.build_number(b.fetch("attributes").fetch("version")) }
  highest = numbers.max_by { |v| version_key(v) }
  unless requested.nil? || requested.empty?
    ASC.build_number(requested)
    raise ASC::Error, "Requested build number is not newer than ASC" if highest && (version_key(requested) <=> version_key(highest)) <= 0
    return requested
  end
  return "1" unless highest
  parts = highest.split(".")
  (parts[0..-2] + [(parts[-1].to_i + 1).to_s]).join(".")
end

if $PROGRAM_NAME == __FILE__
  app = ASC.find_app(ASC.require_env("BUNDLE_ID"))
  puts next_build_number(ASC.all_builds(app.fetch("id")), ENV["REQUESTED_BUILD"])
end

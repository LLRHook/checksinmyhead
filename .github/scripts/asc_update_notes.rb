#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "asc_api"

module ASCNotes
  EDITABLE = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED INVALID_BINARY].freeze
  LOCKED = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze
  module_function

  def attached!(version_id, build_id)
    attached = ASC.get("/v1/appStoreVersions/#{ASC.identifier(version_id)}/relationships/build").dig("data", "id")
    raise ASC::Error, "Notes target has a different attached build" unless attached == build_id
  end

  def version(app_id, version_string)
    versions = ASC.pages("/v1/apps/#{ASC.identifier(app_id)}/appStoreVersions", { "filter[platform]" => "IOS", "limit" => "200" })
    matches = versions.select { |v| v.dig("attributes", "versionString") == version_string }
    raise ASC::Error, "Missing/ambiguous notes version" unless matches.length == 1
    raise ASC::Error, "Notes version has wrong platform" unless matches[0].dig("attributes", "platform") == "IOS"
    matches[0]
  end

  def write(version_id, notes, locale)
    locs = ASC.pages("/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations", { "limit" => "200" })
    if locs.empty?
      created = ASC.post("/v1/appStoreVersionLocalizations", {
        data: { type: "appStoreVersionLocalizations", attributes: { locale: locale, whatsNew: notes },
                relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version_id } } } }
      }).fetch("data")
      locs = [created]
    else
      locs.each do |loc|
        ASC.patch("/v1/appStoreVersionLocalizations/#{ASC.identifier(loc.fetch('id'))}", {
          data: { type: "appStoreVersionLocalizations", id: loc.fetch("id"), attributes: { whatsNew: notes } }
        })
      end
    end
    locs.each do |loc|
      actual = ASC.get("/v1/appStoreVersionLocalizations/#{loc.fetch('id')}").fetch("data")
      raise ASC::Error, "Notes readback mismatch" unless actual.dig("attributes", "whatsNew") == notes
    end
  end

  def pending(app_id, version_id)
    subs = ASC.pages("/v1/reviewSubmissions", { "filter[app]" => app_id, "limit" => "200" })
    matches = subs.select do |s|
      next false unless %w[READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW].include?(s.dig("attributes", "state")) && s.dig("attributes", "platform") == "IOS"
      items = ASC.pages("/v1/reviewSubmissions/#{ASC.identifier(s.fetch('id'))}/items", { "limit" => "200" })
      items.any? { |i| i.dig("relationships", "appStoreVersion", "data", "id") == version_id }
    end
    raise ASC::Error, "Missing/ambiguous attached review submission" unless matches.length == 1
    matches[0]
  end

  def run(context, notes:, allow_cancel: false, resubmit: true, locale: "en-US", pause: ->(s) { sleep s }, reauthorize:)
    app_id = context.fetch("app_id"); proven = context.fetch("origin").fetch("asc")
    version_string = proven.fetch("version"); build_id = proven.fetch("build_id")
    v = version(app_id, version_string); version_id = ASC.identifier(v.fetch("id"))
    attached!(version_id, build_id)
    state = v.dig("attributes", "appStoreState") || v.dig("attributes", "appVersionState")
    return { "verified" => true, "writes" => 0 } if context.fetch("verification_only")
    if LOCKED.include?(state)
      # No optimistic write/cancel is attempted in a locked state without consent.
      raise ASC::Error, "Locked review requires explicit allow_cancel consent" unless allow_cancel
      submission = pending(app_id, version_id)
      reauthorize.call
      attached!(version_id, build_id)
      id = ASC.identifier(submission.fetch("id"))
      ASC.patch("/v1/reviewSubmissions/#{id}", { data: { type: "reviewSubmissions", id: id, attributes: { canceled: true } } })
      unlocked = false
      12.times do
        current = version(app_id, version_string)
        attached!(version_id, build_id)
        s = current.dig("attributes", "appStoreState") || current.dig("attributes", "appVersionState")
        if EDITABLE.include?(s)
          unlocked = true; break
        end
        pause.call(10)
      end
      raise ASC::Error, "Cancellation did not unlock version within deadline" unless unlocked
      reauthorize.call
      write(version_id, notes, locale)
      attached!(version_id, build_id)
      if resubmit
        reauthorize.call
        id = submit_for_review(app_id, version_id)
        verify_review_submission(id, version_id, build_id)
      end
    elsif EDITABLE.include?(state)
      reauthorize.call
      write(version_id, notes, locale)
    else
      raise ASC::Error, "App Store notes state is not editable"
    end
    attached!(version_id, build_id)
    { "verified" => true, "build_id" => build_id }
  end
end

abort "Use the verified asc_delivery.rb entry point" if $PROGRAM_NAME == __FILE__

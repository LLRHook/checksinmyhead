# frozen_string_literal: true

ENV["BUNDLE_ID"] = "com.example.app"
ENV["VERSION_STRING"] = "1.4.0"
ENV["BUILD_NUMBER"] = "25"
ENV["RELEASE_TYPE"] = "AFTER_APPROVAL"

require "minitest/autorun"
require_relative "asc_release"

class ASCReleaseTest < Minitest::Test
  def test_reuses_exact_editable_version_without_mutating_it
    exact = app_store_version("version-140", "1.4.0", "PREPARE_FOR_SUBMISSION")

    ASC.stub(:get, { "data" => [exact] }) do
      ASC.stub(:patch, ->(*) { flunk "an exact version must not be repurposed" }) do
        assert_same exact, find_editable_version("app-id", "1.4.0")
      end
    end
  end

  def test_repurposes_rejected_version_before_attaching_new_build
    rejected = app_store_version("version-130", "1.3.0", "REJECTED")
    updated = app_store_version("version-130", "1.4.0", "PREPARE_FOR_SUBMISSION")
    patches = []
    patch = lambda do |path, body|
      patches << [path, body]
      path.end_with?("/relationships/build") ? {} : { "data" => updated }
    end

    result = ASC.stub(:get, { "data" => [rejected] }) do
      ASC.stub(:patch, patch) do
        find_editable_version("app-id", "1.4.0")
      end
    end

    assert_same updated, result
    assert_equal [
      ["/v1/appStoreVersions/version-130/relationships/build", { data: nil }],
      [
        "/v1/appStoreVersions/version-130",
        {
          data: {
            type: "appStoreVersions",
            id: "version-130",
            attributes: {
              versionString: "1.4.0",
              releaseType: "AFTER_APPROVAL"
            }
          }
        }
      ]
    ], patches
  end

  def test_resets_exact_rejected_version_before_reattaching_build
    rejected = app_store_version("version-140", "1.4.0", "REJECTED")
    updated = app_store_version("version-140", "1.4.0", "PREPARE_FOR_SUBMISSION")
    patches = []
    patch = lambda do |path, body|
      patches << [path, body]
      path.end_with?("/relationships/build") ? {} : { "data" => updated }
    end

    result = ASC.stub(:get, { "data" => [rejected] }) do
      ASC.stub(:patch, patch) do
        find_editable_version("app-id", "1.4.0")
      end
    end

    assert_same updated, result
    assert_equal [
      ["/v1/appStoreVersions/version-140/relationships/build", { data: nil }],
      [
        "/v1/appStoreVersions/version-140",
        {
          data: {
            type: "appStoreVersions",
            id: "version-140",
            attributes: {
              versionString: "1.4.0",
              releaseType: "AFTER_APPROVAL"
            }
          }
        }
      ]
    ], patches
  end

  def test_refuses_to_replace_different_version_still_in_preparation
    open = app_store_version("version-131", "1.3.1", "PREPARE_FOR_SUBMISSION")

    error = ASC.stub(:get, { "data" => [open] }) do
      assert_raises(ASC::Error) { find_editable_version("app-id", "1.4.0") }
    end

    assert_match "Version 1.3.1 is already open for editing", error.message
  end

  def test_verifies_version_build_and_submitted_review_state
    get = lambda do |path, _params = {}|
      case path
      when "/v1/appStoreVersions/version-141"
        { "data" => app_store_version("version-141", "1.4.0", "WAITING_FOR_REVIEW") }
      when "/v1/appStoreVersions/version-141/relationships/build"
        { "data" => { "type" => "builds", "id" => "build-26" } }
      when "/v1/reviewSubmissions/submission-1"
        {
          "data" => {
            "type" => "reviewSubmissions",
            "id" => "submission-1",
            "attributes" => { "state" => "WAITING_FOR_REVIEW", "submittedDate" => "2026-08-29T20:00:00Z" }
          }
        }
      else
        flunk "unexpected GET #{path}"
      end
    end

    result = ASC.stub(:get, get) do
      verify_review_submission("submission-1", "version-141", "build-26", attempts: 1, interval: 0)
    end

    assert_equal "WAITING_FOR_REVIEW", result[:submission_state]
  end

  private

  def app_store_version(id, version_string, state)
    {
      "type" => "appStoreVersions",
      "id" => id,
      "attributes" => {
        "versionString" => version_string,
        "appStoreState" => state
      }
    }
  end
end

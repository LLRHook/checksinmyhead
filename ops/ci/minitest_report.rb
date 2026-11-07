# frozen_string_literal: true
# Retain real runner class/method IDs during the single Minitest execution.
require "json"
require "minitest"

module Minitest
  class DeliveryReporter < AbstractReporter
    def initialize
      super
      @cases = []
      @occurrences = Hash.new(0)
    end

    def record(result)
      family = "#{result.klass}##{result.name}"
      @occurrences[family] += 1
      status = result.skipped? ? "skip" : (result.passed? ? "pass" : "fail")
      @cases << { id: "#{family}/invocation:#{@occurrences[family]}", family: family, status: status }
    end

    def report
      File.write(ENV.fetch("CASE_REPORT"), JSON.generate({
        complete: true, success: @cases.all? { |c| c[:status] == "pass" },
        tests_run: @cases.length, started: @cases.map { |c| c[:id] }, cases: @cases
      }) + "\n")
    end
  end

  def self.plugin_delivery_init(_options)
    reporter << DeliveryReporter.new
  end
  extensions << "delivery"
end

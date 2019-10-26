# frozen_string_literal: true

require "github_requests"

# TODO: rename all modules representing API resources to have a
# `Resource` suffix. E.g. CheckRuns -> CheckRunsResource
module CheckRuns
  class Base
    include GitHubRequests
    include ClassLoggable

    attr_reader :run

    # @param run [DataObjects::CheckRunInfo] check run metadata object
    def initialize(run)
      @run = run
    end
  end
end

require "check_runs/create"
require "check_runs/run"
require "check_runs/complete"

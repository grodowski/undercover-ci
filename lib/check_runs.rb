# frozen_string_literal: true

require "github_requests"

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

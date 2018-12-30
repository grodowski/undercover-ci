# frozen_string_literal: true

require "github_requests"

module CheckRuns
  class Base
    include GitHubRequests

    attr_reader :run

    def initialize(run)
      @run = run
    end
  end
end

require "check_runs/create"
require "check_runs/run"
require "check_runs/complete"

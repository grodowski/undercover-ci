# frozen_string_literal: true

require "github_requests"

# TODO: rename all modules representing API resources to have a
# `Resource` suffix. E.g. CheckRuns -> CheckRunsResource
module CheckRuns
  class Base
    include GithubRequests
    include ClassLoggable

    attr_reader :run

    # @param run [DataObjects::CheckRunInfo] check run metadata object
    def initialize(run)
      @run = run
    end

    def details_url
      # TODO: figure out the default_url_options problem!
      Rails.application.routes.url_helpers.check_url(
        run.external_id,
        host: "https://undercover-ci.com"
        # host: Rails.application.config.action_controller.default_url_options[:host]
      )
    end
  end
end

require "check_runs/create"
require "check_runs/run"
require "check_runs/complete"
require "check_runs/canceled"

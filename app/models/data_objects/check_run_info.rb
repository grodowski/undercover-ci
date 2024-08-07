# frozen_string_literal: true

require "ostruct"

module DataObjects
  CHECK_RUN_INFO_ATTRIBUTES = %i[
    full_name
    sha
    compare
    installation_id
    created_at
    payload
    state
    external_id
    last_ts
    nodes
    state_log
  ].freeze

  # TODO: consider refactoring into OpenStruct/Class with named attrs
  CheckRunInfo = Struct.new(*CHECK_RUN_INFO_ATTRIBUTES) do
    def self.from_webhook(payload)
      payload = OpenStruct.new(payload)
      installation_id = payload.installation.fetch("id")
      full_name = payload.repository.fetch("full_name")
      sha = payload.check_suite.fetch("head_sha")
      compare = find_base_sha(payload)
      new(full_name, sha, compare, installation_id, nil, payload)
    end

    def self.from_coverage_check(db_check)
      new(
        db_check.repo.fetch("full_name"),
        db_check.head_sha,
        db_check.base_sha.presence || db_check.default_branch,
        db_check.installation.installation_id,
        db_check.created_at,
        nil, # TODO: ~load repository and check_suite from jsonb columns
        db_check.state,
        db_check.id.to_s,
        db_check.state_log.last&.fetch("ts"),
        db_check.nodes, # TODO: wrap AR models with a dedicated read model
        db_check.state_log
      )
    end

    def self.find_base_sha(payload)
      pr_base_sha = payload.check_suite.dig("pull_requests", 0, "base", "sha")
      if pr_base_sha
        pr_base_sha
      elsif payload.check_suite.fetch("head_branch") != payload.repository.fetch("default_branch")
        payload.repository.fetch("default_branch")
      else
        # This used to be `payload.check_suite.fetch("before")` which didn't work
        # for force pushes, as the check suite delivered from GitHub kept the old base sha.
        "HEAD~1"
      end
    end

    def success?
      num_warnings.zero?
    end

    def num_warnings
      @num_warnings ||= nodes.flagged.size
    end

    def error_message
      return unless state == :canceled

      failed_transition = state_log.find { _1["to"] == "canceled" }
      failed_transition["via"] if failed_transition
    end

    alias_method :to_s, :inspect
  end
end

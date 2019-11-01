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
  ].freeze

  # rubocop:disable Metrics/BlockLength
  CheckRunInfo = Struct.new(*CHECK_RUN_INFO_ATTRIBUTES) do
    def self.from_webhook(payload)
      payload = OpenStruct.new(payload)
      installation_id = payload.installation.fetch("id")
      full_name = payload.repository.fetch("full_name")
      sha = payload.check_suite.fetch("head_sha")
      compare = find_base_sha(payload)
      new(full_name, sha, compare, installation_id, nil, payload)
    end

    def self.from_coverage_check(job)
      new(
        job.repo.fetch("full_name"),
        job.head_sha,
        job.base_sha.presence || job.default_branch,
        job.installation.installation_id,
        job.created_at,
        nil # TODO: ~load repository and check_suite from jsonb columns
      )
    end

    def self.find_base_sha(payload)
      pr_base_sha = payload.check_suite.dig("pull_requests", 0, "base", "ref")
      if pr_base_sha
        pr_base_sha
      elsif payload.check_suite.fetch("head_branch") != payload.repository.fetch("default_branch")
        payload.repository.fetch("default_branch")
      else
        payload.check_suite.fetch("before") # sha of HEAD~1
      end
    end

    alias_method :to_s, :inspect
  end
  # rubocop:enable Metrics/BlockLength
end

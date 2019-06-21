# frozen_string_literal: true

require "ostruct"

module DataObjects
  CheckRunInfo = Struct.new(:full_name, :sha, :compare, :installation_id, :payload) do
    def self.from_webhook(payload)
      payload = OpenStruct.new(payload)
      installation_id = payload.installation.fetch("id")
      full_name = payload.repository.fetch("full_name")
      sha = payload.check_suite.fetch("head_sha")
      compare = payload.check_suite["pull_requests"]&.first&.dig("base", "ref")
      new(full_name, sha, compare, installation_id, payload)
    end

    def self.from_coverage_check(job)
      new(
        job.repo.fetch("full_name"),
        job.head_sha,
        job.base_sha.presence || job.default_branch,
        job.installation_id
      )
    end

    alias_method :to_s, :inspect
  end
end

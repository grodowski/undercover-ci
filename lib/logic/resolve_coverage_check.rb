# frozen_string_literal: true

module Logic
  # Finds the CoverageCheck a coverage upload belongs to. A pull request opened from a fork has
  # no check yet, because GitHub sends no check_suite event for it, so a verified pull request
  # number lets the upload start one. The same number backfills checks that were created by a
  # branch push before the pull request existed.
  class ResolveCoverageCheck
    def self.call(repo_full_name, sha, pull_request_number)
      new(repo_full_name, sha, pull_request_number).resolve
    end

    attr_reader :repo_full_name, :sha, :pull_request_number

    def initialize(repo_full_name, sha, pull_request_number)
      @repo_full_name = repo_full_name
      @sha = sha
      @pull_request_number = pull_request_number
    end

    def resolve
      coverage_check = existing_coverage_check
      return start_from_upload unless coverage_check

      backfill_pull_request_number(coverage_check)
      coverage_check
    end

    private

    def existing_coverage_check
      CoverageCheck.where("repo @> ?", {full_name: repo_full_name}.to_json)
                   .where(head_sha: sha).first
    end

    def start_from_upload
      return unless pull_request_number

      Logic::StartCheckRunFromUpload.call(repo_full_name, sha, pull_request_number)
    end

    def backfill_pull_request_number(coverage_check)
      return unless pull_request_number
      return if coverage_check.pull_request_number || coverage_check.pull_requests.present?
      return unless Logic::VerifyPullRequestHead.call(
        coverage_check.installation.installation_id, repo_full_name, sha, pull_request_number
      )

      coverage_check.update!(pull_request_number:)
    end
  end
end

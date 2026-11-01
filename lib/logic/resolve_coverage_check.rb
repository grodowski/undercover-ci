# frozen_string_literal: true

module Logic
  # Finds the CoverageCheck a coverage upload belongs to. A pull request opened from a fork has
  # no check yet, because GitHub sends no check_suite event for it, so a verified pull request
  # number lets the upload start one.
  module ResolveCoverageCheck
    module_function

    def call(repo_full_name, sha, pull_request_number, base_ref: nil, head_ref: nil)
      existing = CoverageCheck.for_repo_sha(repo_full_name, sha)
      if existing
        record_pull_request(existing, pull_request_number) if pull_request_number
        return existing
      end
      return if pull_request_number.nil?

      Logic::StartCheckRunFromUpload.call(repo_full_name, sha, pull_request_number, base_ref:, head_ref:)
    end

    # A branch pushed before its pull request was opened gets a check_suite without pull requests,
    # and GitHub sends no new one when the pull request is opened
    def record_pull_request(coverage_check, pull_request_number)
      return if coverage_check.pull_request_number || coverage_check.pull_requests.any?
      return unless Logic::VerifyPullRequestHead.call(
        coverage_check.installation.installation_id, coverage_check.repo_full_name, coverage_check.head_sha,
        pull_request_number
      )

      coverage_check.update!(pull_request_number:)
    end
  end
end

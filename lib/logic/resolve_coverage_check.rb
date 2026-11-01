# frozen_string_literal: true

module Logic
  # Finds the CoverageCheck a coverage upload belongs to. A pull request opened from a fork has
  # no check yet, because GitHub sends no check_suite event for it, so a verified pull request
  # number lets the upload start one.
  module ResolveCoverageCheck
    module_function

    def call(repo_full_name, sha, pull_request_number, base_ref: nil, head_ref: nil)
      existing = CoverageCheck.for_repo_sha(repo_full_name, sha)
      return existing if existing || pull_request_number.nil?

      Logic::StartCheckRunFromUpload.call(repo_full_name, sha, pull_request_number, base_ref:, head_ref:)
    end
  end
end

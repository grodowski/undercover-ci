# frozen_string_literal: true

# Optional pull request params of an unauthenticated coverage upload. Invalid values are dropped.
module CoverageUploadParams
  extend ActiveSupport::Concern

  private

  # Only an upload may start or update a check, never a cancellation
  def uploaded_pull_request_number
    return unless action_name == "create"

    number = params[:pull_request_number].to_s
    number.to_i if number.match?(/\A[1-9]\d{0,8}\z/)
  end

  def uploaded_branch(param)
    branch = params[param]
    branch if branch.is_a?(String) && git_branch_name?(branch)
  end

  # git's own rules. Checking refs/heads/<name> avoids the @{-N} expansion of --branch, which
  # also rejects a leading "-".
  def git_branch_name?(name)
    name.length <= 255 && !name.start_with?("-") &&
      system("git", "check-ref-format", "refs/heads/#{name}", out: File::NULL, err: File::NULL)
  end
end

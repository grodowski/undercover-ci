# frozen_string_literal: true

# Optional pull request params of an unauthenticated coverage upload. Invalid values are dropped.
module CoverageUploadParams
  extend ActiveSupport::Concern

  # A conservative subset of git's branch name rules
  BRANCH_NAME = /\A(?![-.\/])(?!.*(?:\.\.|\/\/|\/\.))(?!.*(?:\.lock|[.\/])\z)[A-Za-z0-9._\/-]{1,255}\z/

  private

  # Only an upload may start or update a check, never a cancellation
  def uploaded_pull_request_number
    return unless action_name == "create"

    number = params[:pull_request_number].to_s
    number.to_i if number.match?(/\A[1-9]\d{0,8}\z/)
  end

  def uploaded_branch(param)
    branch = params[param]
    branch if branch.is_a?(String) && branch.match?(BRANCH_NAME)
  end
end

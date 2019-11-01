# frozen_string_literal: true

module ApplicationHelper
  def pull_request_or_commit_link(coverage_check)
    base_vs_compare = content_tag("code", coverage_check.head_sha[0..7]) + \
                      " 👉 " + \
                      content_tag("code", (coverage_check.base_sha.try(:[], 0..7) || coverage_check.default_branch))
    repo = coverage_check.repo_full_name
    if coverage_check.pull_requests.any?
      pr_number = coverage_check.check_suite.dig("pull_requests", 0, "number")
      url = "https://github.com/#{repo}/pull/#{pr_number}/checks"
    else
      url = "https://github.com/#{repo}/commit/#{coverage_check.head_sha}"
    end
    link_to base_vs_compare, url
  end
end

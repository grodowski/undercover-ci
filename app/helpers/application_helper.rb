# frozen_string_literal: true

module ApplicationHelper
  def pull_request_or_commit_link(coverage_check)
    repo = coverage_check.repo_full_name
    pr = coverage_check.check_suite&.dig("pull_requests", 0)

    if pr
      pr_number = pr["number"]
      base_vs_compare = content_tag("code", "#{pr['head']['ref']} @ #{coverage_check.head_sha[0..7]}") + \
                        " 👉 " + \
                        content_tag("code", pr["base"]["ref"])
      url = "https://github.com/#{repo}/pull/#{pr_number}/checks"
    else
      base_vs_compare = content_tag("code", coverage_check.head_sha[0..7]) + \
                        " 👉 " + \
                        content_tag("code", (coverage_check.base_sha.try(:[], 0..7) || coverage_check.default_branch))
      url = "https://github.com/#{repo}/commit/#{coverage_check.head_sha}"
    end
    link_to base_vs_compare, url
  end

  def coverage_check_result_text(_check)
    # TODO: ✅ / 🚨 (n warnings) based on stored result, once we do it!
    nil
  end

  def nav_link_with_state(link_text, path, **html_args)
    class_names = ["nav-link"]
    class_names << "active" if request.path == path
    content_tag(:li, class: "nav-item") do
      link_to link_text, path, {class: class_names.join(" ")}.merge(html_args)
    end
  end
end

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

  def coverage_result_badge(check)
    warn_count = check.flagged_nodes_count
    badge_type = warn_count.zero? ? "badge-success" : "badge-warning"
    content_tag(:span, class: "badge #{badge_type}") do
      "#{warn_count} #{'warning'.pluralize(warn_count)}"
    end
  end

  def badge_label_for_node(node)
    flag = node.flagged? ? "warning" : "info"
    content_tag(:span, class: "badge badge-#{flag}") do
      flag
    end
  end

  def format_node_coverage(node)
    # TODO: store coverage array to display lines?
    color, text = if node.coverage == 1.0
                    [:default, ""]
                  elsif node.flagged?
                    [:yellow, ", some changed lines were untested"]
                  else
                    [:blue, ""]
                  end
    color_class = "node-coverage-#{color}"
    content_tag(:span, "#{node.coverage * 100}%", class: color_class) + \
      content_tag(:span, text)
  end

  def nav_link_with_state(link_text, path, **html_args)
    class_names = ["nav-link"]
    class_names << "active" if request.path == path
    content_tag(:li, class: "nav-item") do
      link_to link_text, path, {class: class_names.join(" ")}.merge(html_args)
    end
  end
end

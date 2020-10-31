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
                    [:yellow, " (contains untested diff lines)"]
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

  def gumroad_subscribe_link(installation)
    return unless ENV["FF_SUBSCRIPTION"]

    subscribe_link = link_to(
      "Subscribe",
      "https://gum.co/" \
        "#{Gumroad::SUBSCRIPTION_PRODUCT_PERMALINK}" \
        "?installation_id=#{installation.installation_id}",
      class: "btn btn-primary gumroad-subscribe", target: "_blank"
    )
    subscription = installation.subscription
    return subscribe_link unless subscription

    if subscription.active? && !subscription.trial?
      expires_on_text = if subscription.end_date.present?
                          "(expires on #{subscription.end_date.to_date.to_formatted_s(:long)})"
                        end
      return content_tag :div, "Active license: #{subscription.license_key} #{expires_on_text}"
    end

    content = content_tag(:span)
    if subscription.trial?
      trial_text = if subscription.active?
                     "Trial ends in #{distance_of_time_in_words_to_now(subscription.trial_expiry_date)}: " \
                       "(#{subscription.trial_expiry_date.to_date.to_formatted_s(:long)})"
                   else
                     "Trial expired"
                   end
      content += content_tag(:div, trial_text)
    end

    content + subscribe_link
  end
end

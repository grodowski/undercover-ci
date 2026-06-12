# frozen_string_literal: true

namespace :emails do
  desc "Send weekly summary emails to users with check activity in the past 7 days"
  task weekly_summary: :environment do
    User.find_each do |user|
      next unless user.weekly_summary_enabled?

      checks = user.coverage_checks.complete.last_7d.includes(:nodes).to_a.uniq(&:head_sha)
      next if checks.empty?

      repo_stats = checks.group_by(&:repo_full_name).transform_values do |repo_checks|
        flagged = repo_checks.flat_map { _1.nodes.select(&:flagged) }
        hotspots = flagged
                   .reject { _1.node_name.start_with?("block") }
                   .group_by { [_1.path, _1.node_name] }
                   .transform_values(&:count)
                   .max_by(5) { |_, n| n }
                   .to_h

        {
          passed: repo_checks.count { _1.result == :passed },
          failed: repo_checks.count { _1.result == :failed },
          hotspots: hotspots
        }
      end

      UserMailer.weekly_summary(user, repo_stats).deliver_now
    end
  end
end

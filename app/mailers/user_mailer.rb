# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def weekly_summary(user, repo_stats)
    @user = user
    @repo_stats = repo_stats
    mail(to: user.email, subject: email_subject(repo_stats))
  end

  private

  def email_subject(repo_stats)
    total_failed = repo_stats.values.sum { _1[:failed] }
    top_repo = repo_stats.max_by { |_, s| s[:failed] }.first
    if total_failed.positive?
      "UndercoverCI: #{top_repo} — #{total_failed} check#{'s' if total_failed != 1} had warnings this week"
    else
      "UndercoverCI: all checks passed this week"
    end
  end
end

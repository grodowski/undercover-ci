# frozen_string_literal: true

desc "Monitor old coverage checks and log statistics"
task monitor_checks: :environment do
  ten_minutes_ago = 10.minutes.ago

  # Count in_progress checks older than 10 minutes
  old_in_progress_count = CoverageCheck.where(state: :in_progress)
                                      .where("created_at < ?", ten_minutes_ago)
                                      .count

  # Count queued checks older than 10 minutes
  old_queued_count = CoverageCheck.where(state: :queued)
                                 .where("created_at < ?", ten_minutes_ago)
                                 .count

  # Find oldest queued check
  oldest_queued = CoverageCheck.where(state: :queued)
                              .order(:created_at)
                              .first

  oldest_queued_age = if oldest_queued
                       Time.current - oldest_queued.created_at
                     else
                       0
                     end

  Rails.logger.info "Check Monitor Stats:"
  Rails.logger.info "  - In-progress checks older than 10 minutes: #{old_in_progress_count}"
  Rails.logger.info "  - Queued checks older than 10 minutes: #{old_queued_count}"
  Rails.logger.info "  - Oldest queued check age: #{oldest_queued_age.round(2)} seconds"

  puts "Check Monitor Stats:"
  puts "  - In-progress checks older than 10 minutes: #{old_in_progress_count}"
  puts "  - Queued checks older than 10 minutes: #{old_queued_count}"
  puts "  - Oldest queued check age: #{oldest_queued_age.round(2)} seconds"
end
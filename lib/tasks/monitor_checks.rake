# frozen_string_literal: true

desc "Monitor old coverage checks and log statistics"
task monitor_checks: :environment do # rubocop:disable Metrics/BlockLength
  ten_minutes_ago = 10.minutes.ago

  # Count in_progress checks that transitioned to in_progress more than 10 minutes ago
  old_in_progress_count = CoverageCheck.where(state: :in_progress).select do |check|
    in_progress_transition = check.state_log.find { |log| log["to"] == "in_progress" }
    in_progress_transition && Time.parse(in_progress_transition["ts"]) < ten_minutes_ago
  end.count

  # Count queued checks that transitioned to queued more than 10 minutes ago
  old_queued_count = CoverageCheck.where(state: :queued).select do |check|
    queued_transition = check.state_log.find { |log| log["to"] == "queued" }
    queued_transition && Time.parse(queued_transition["ts"]) < ten_minutes_ago
  end.count

  # Find oldest queued check based on state transition timestamp
  oldest_queued = CoverageCheck.where(state: :queued).min_by do |check|
    queued_transition = check.state_log.find { |log| log["to"] == "queued" }
    Time.parse(queued_transition["ts"])
  end

  oldest_queued_age = if oldest_queued
                        queued_transition = oldest_queued.state_log.find { |log| log["to"] == "queued" }
                        if queued_transition
                          Time.current - Time.parse(queued_transition["ts"])
                        else
                          0
                        end
                      else
                        0
                      end

  Rails.logger.warn "In-progress checks older than 10 minutes: #{old_in_progress_count}" if old_in_progress_count.any?
  Rails.logger.warn "Queued checks older than 10 minutes: #{old_queued_count}" if old_queued_count.any?
  Rails.logger.warn "Oldest queued check age: #{oldest_queued_age.round(2)} seconds" if oldest_queued_age > 30

  puts "Check Monitor Stats:"
  puts "  - In-progress checks older than 10 minutes: #{old_in_progress_count}"
  puts "  - Queued checks older than 10 minutes: #{old_queued_count}"
  puts "  - Oldest queued check age: #{oldest_queued_age.round(2)} seconds"
end

# frozen_string_literal: true

def check_result(check)
  return unless check.state == :complete

  check.nodes.any?(&:flagged?) ? "failed" : "passed"
end

desc "Backfill CoverageCheck.result"
task backfill_result: :environment do
  n = 0
  CoverageCheck.where.not(installation: nil).where(state: :complete).find_each(batch_size: 500) do |check|
    check.update_column(:result, check_result(check))
    print "." if (n % 1000).zero?
    n += 1
  end
end

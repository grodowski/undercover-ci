# frozen_string_literal: true

class ExpireCheckJob < ApplicationJob
  queue_as :default

  def perform(coverage_check_id)
    coverage_check = CoverageCheck.find(coverage_check_id)
    return unless coverage_check.state == :awaiting_coverage

    Logic::UpdateCoverageCheckState.new(coverage_check).expire
  end
end

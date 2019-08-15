# frozen_string_literal: true

module Logic
  StateTransisionError = Class.new(StandardError)

  class UpdateCoverageCheckState
    attr_reader :coverage_check

    def initialize(coverage_check)
      @coverage_check = coverage_check
    end

    def await_coverage
      transition(:created, :awaiting_coverage)
    end

    def start
      transition(:awaiting_coverage, :in_progress)
    end

    def restart
      transition(:in_progress, :in_progress, "restart")
    end

    def complete
      transition(:in_progress, :complete)
    end

    private

    def transition(expectd_old_state, new_state, via = nil)
      old_state = coverage_check.state

      unless expectd_old_state == old_state
        raise StateTransisionError, "cannot transition from #{old_state} to #{new_state}"
      end

      coverage_check.state = new_state
      coverage_check.state_log << {
        ts: Time.now.iso8601,
        from: old_state,
        to: new_state,
        via: via
      }
      coverage_check.save!
    end
  end
end

# frozen_string_literal: true

module Logic
  StateTransisionError = Class.new(StandardError)

  class UpdateCoverageCheckState
    attr_reader :coverage_check

    def initialize(coverage_check)
      @coverage_check = coverage_check
    end

    def queue
      set_state(:queued)
    end

    def start
      set_state(:in_progress)
    end

    def restart
      set_state(:in_progress, "restart")
    end

    def complete
      set_state(:complete)
    end

    private

    def set_state(new_state, via = nil)
      prev_state = coverage_check.state
      coverage_check.state = new_state
      coverage_check.state_log << {
        ts: Time.now.iso8601,
        from: prev_state,
        to: new_state,
        via: via
      }
      coverage_check.save!
    end
  end
end

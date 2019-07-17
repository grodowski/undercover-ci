# frozen_string_literal: true

module Logic
  class UpdateRunState
    VALID_STATES = %w[created queued in_progress aborted error].freeze
    ABORTABLE = %w[created queued in_progress].freeze
    ERRORABLE = ABORTABLE

    attr_reader :error_message

    # @param run_info [DataObjects::CheckRunInfo]
    # @return ?
    def initialize(coverage_check)
      @coverage_check = coverage_check
      @run_info = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)
      @state = run_info.state # TODO
    end

    def queued
      return false unless precondition_met?(%w[created], "queued")

      update_state("queued")
    end

    def in_progress
      return false unless precondition_met?(%w[created queued], "in_progress")

      update_state("in_progress")
    end

    def completed
      return false unless precondition_met?(%w[in_progress], "completed")

      update_state("completed")
    end

    def error(reason)
      return false unless precondition_met?(ERRORABLE, "error")

      update_state("error", reason)
    end

    def abort(reason)
      return false unless precondition_met?(ABORTABLE, "aborted")

      update_state("aborted", reason)
    end

    private

    def update_state(to_state, reason = nil)
      @coverage_check.state = to_state
      @coverage_check.event_log["state_log"] << {
        from: @state,
        to: to_state,
        reason: reason
      }
      @coverage_check.save!
    end

    def precondition_met?(from, to)
      return true if from.include?(@state)

      @error_message = "Could not transition run state from #{from} to #{to}"
      false
    end
  end
end

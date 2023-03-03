# frozen_string_literal: true

module Logic
  StateTransisionError = Class.new(StandardError)

  class StateMachine
    attr_reader :record

    def initialize(record)
      @record = record
    end

    private

    def transition(expectd_old_state, new_state, via = nil)
      old_state = record.state

      unless old_state.in?(Array(expectd_old_state))
        raise StateTransisionError,
              "cannot transition #{record.class}:#{record.id} from #{old_state} to #{new_state}"
      end

      record.state = new_state
      record.state_log << {
        ts: Time.now.utc.iso8601,
        from: old_state,
        to: new_state,
        via:
      }
      record.save!
    end
  end
end

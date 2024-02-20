# frozen_string_literal: true

module Logic
  class UpdateCoverageCheckState < StateMachine
    def await_coverage
      transition(:created, :awaiting_coverage)
    end

    def start
      transition(%i[canceled awaiting_coverage in_progress], :in_progress)
    end

    def restart
      transition(:in_progress, :awaiting_coverage, "restart")
    end

    def complete
      transition(:in_progress, :complete)
    end

    def cancel(message = nil)
      transition(%i[created awaiting_coverage in_progress], :canceled, message)
    end
  end
end

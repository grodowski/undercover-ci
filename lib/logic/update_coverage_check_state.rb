# frozen_string_literal: true

module Logic
  class UpdateCoverageCheckState < StateMachine
    def await_coverage
      transition(:created, :awaiting_coverage)
    end

    def expire
      transition(%i[awaiting_coverage in_progress], :expired)
    end

    def start
      transition(:awaiting_coverage, :in_progress)
    end

    def restart
      transition(:in_progress, :awaiting_coverage, "restart")
    end

    def complete
      transition(:in_progress, :complete)
    end

    def cancel
      transition(%i[created awaiting_coverage in_progress], :canceled)
    end
  end
end

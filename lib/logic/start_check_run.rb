# frozen_string_literal: true

module Logic
  class StartCheckRun
    include ClassLoggable

    def self.call(check_run_info)
      new(check_run_info).create_and_queue_check_run
    end

    attr_reader :check_run_info

    def initialize(check_run_info)
      @check_run_info = check_run_info
    end

    def create_and_queue_check_run
      find_installation
      coverage_check = CoverageCheck.find_or_initialize_by(
        head_sha: check_run_info.sha,
        installation: @installation
      )

      unless coverage_check.state == :created
        log "StartCheckRun exiting early, #{check_run_info} is #{coverage_check.state}"
        return
      end

      coverage_check.repo = check_run_info.payload&.repository
      coverage_check.save!

      Logic::UpdateCoverageCheckState.new(coverage_check).await_coverage
      CreateCheckRunJob.perform_later(coverage_check.id)
    end

    private

    def find_installation
      @installation = Installation.find_by!(installation_id: check_run_info.installation_id)
    end
  end
end

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
      build_coverage_check

      unless coverage_check.state == :created
        log "StartCheckRun exiting early, #{check_run_info} is #{coverage_check.state}"
        return
      end

      coverage_check.repo = check_run_info.payload&.repository
      coverage_check.check_suite = check_run_info.payload&.check_suite
      coverage_check.save!

      Logic::UpdateCoverageCheckState.new(coverage_check).await_coverage
      CreateCheckRunJob.perform_later(coverage_check.id)

      ExpireCheckJob.set(wait:).perform_later(coverage_check.id)
    end

    private

    attr_reader :coverage_check, :installation

    def wait
      return ExpireCheckJob::INACTIVE_WAIT unless coverage_check.installation_active?
      return installation.expire_check_job_wait_minutes.minutes if installation.expire_check_job_wait_minutes

      ExpireCheckJob::DEFAULT_WAIT
    end

    def find_installation
      @installation = Installation.find_by!(installation_id: check_run_info.installation_id)
    end

    def build_coverage_check
      @coverage_check = @installation.coverage_checks.find_or_initialize_by(
        head_sha: check_run_info.sha,
        base_sha: check_run_info.compare
      )
    end
  end
end

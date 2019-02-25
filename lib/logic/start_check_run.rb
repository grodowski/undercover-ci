# frozen_string_literal: true

module Logic
  class StartCheckRun
    def self.call(check_run_info)
      new(check_run_info).create_and_queue_check_run
    end

    attr_reader :check_run_info

    def initialize(check_run_info)
      @check_run_info = check_run_info
    end

    def create_and_queue_check_run
      report = CoverageReportJob.find_or_initialize_by(
        commit_sha: check_run_info.sha,
        installation_id: check_run_info.installation_id
      )
      report.repo = check_run_info.payload&.repository
      report.save!
      CreateCheckRunJob.perform_later(report.id)
    end
  end
end

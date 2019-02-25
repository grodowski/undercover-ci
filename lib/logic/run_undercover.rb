# frozen_string_literal: true

module Logic
  class RunUndercover
    def self.call(coverage_report_job)
      new(coverage_report_job).run_undercover
    end

    attr_reader :coverage_report_job, :run

    def initialize(coverage_report_job)
      @coverage_report_job = coverage_report_job
      @run = Hooks::CheckRunInfo.from_coverage_report_job(coverage_report_job)
    end

    def run_undercover
      validate_run

      Rails.logger.info "CheckRuns::Run post #{run} job_id: #{coverage_report_job.id}"
      CheckRuns::Run.new(run).post

      clone_repo
      report = run_cmd

      # TODO: needs lcov path as argument
      # Rails.logger.info "Undercover validate #{report.validate()}"
      Rails.logger.info "Undercover warnigns #{report.build_warnings}"

      Rails.logger.info "Completing analysis... #{run} job_id: #{coverage_report_job.id}"
      CheckRuns::Complete.new(run).post

      # Cleanup
      # - remove /tmp clone and lcov
    end

    private

    def validate_run
      # TODO: validate if run can be ran:
      # - was it queued?
      # - lcov present?
      # - repo reachable (ls-remote)?
      true
    end

    # https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/#http-based-git-access-by-an-installation
    def clone_repo
      i_token = CheckRuns::InstallationAccessToken.new(run).get
      FileUtils.remove_entry(repo_path)
      Imagen::Clone.perform(
        "https://x-access-token:#{i_token}@github.com/#{run.full_name}.git",
        repo_path
      )
    end

    def repo_path
      "tmp/job/#{coverage_report_job.id}"
    end

    def lcov_path
      # TODO: fixup lcov storage!
      "tmp/lcov/#{coverage_report_job.id}/project.lcov"
    end

    def run_cmd
      opts = Undercover::Options.new.tap do |opt|
        opt.lcov = lcov_path
        opt.path = repo_path
      end
      changeset = Undercover::Changeset.new("#{repo_path}/.git", "origin/master")
      Undercover::Report.new(changeset, opts).build
    end
  end
end

# frozen_string_literal: true

module Logic
  class RunUndercover
    include ClassLoggable

    RunError = Class.new(StandardError)

    def self.call(coverage_check)
      new(coverage_check).run_undercover
    end

    attr_reader :coverage_check, :run

    def initialize(coverage_check)
      @lcov_tmpfile = Tempfile.new
      @coverage_check = coverage_check
      @run = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)

      raise RunError, "coverage_reports can't be blank" if coverage_check.coverage_reports.empty?

      fetch_report
    end

    def run_undercover
      if coverage_check.state != :awaiting_coverage
        log "exiting early, coverage_check #{coverage_check.id} is #{coverage_check.state}"
        return
      end

      Logic::UpdateCoverageCheckState.new(coverage_check).start

      log "starting run #{run} job_id: #{coverage_check.id}"
      CheckRuns::Run.new(run).post

      clone_repo
      checkout

      report = run_undercover_cmd
      warnings = report.flagged_results
      log "undercover warnings: #{warnings.size}, " \
          "total nodes: #{report.all_results.size}"
      log "completing analysis... #{run} job_id: #{coverage_check.id}"

      # TODO: improve error handling with transactions
      Logic::SaveResults.call(coverage_check, report)
      run_with_results = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)
      CheckRuns::Complete.new(run_with_results).post(report)
      Logic::UpdateCoverageCheckState.new(coverage_check).complete
      teardown
      log "teardown complete #{run} job_id: #{coverage_check.id}"
    end

    private

    def fetch_report
      # In Rails 6 this will become `coverage_report_jov.coverage_reports.last.open`
      @lcov_tmpfile.write(coverage_check.coverage_reports.last.download)
      @lcov_tmpfile.flush
    end

    # https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/#http-based-git-access-by-an-installation
    def clone_repo
      FileUtils.mkdir_p(repo_path)

      i_token = CheckRuns::InstallationAccessToken.new(run).get
      FileUtils.remove_entry(repo_path)
      Imagen::Clone.perform(
        "https://x-access-token:#{i_token}@github.com/#{run.full_name}.git",
        repo_path
      )
    end

    def checkout
      repo = Rugged::Repository.new(repo_path)
      branch = repo.create_branch("undercover-ci", run.sha)
      repo.checkout(branch)
    end

    def teardown
      @lcov_tmpfile.close
    end

    def repo_path
      "tmp/job/#{coverage_check.id}"
    end

    def run_undercover_cmd
      opts = Undercover::Options.new.tap do |opt|
        opt.lcov = @lcov_tmpfile.path
        opt.path = repo_path
      end
      changeset = Undercover::Changeset.new("#{repo_path}/.git", @run.compare)
      Undercover::Report.new(changeset, opts).build
    end
  end
end

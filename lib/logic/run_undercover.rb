# frozen_string_literal: true

module Logic
  class RunUndercover
    RunError = Class.new(StandardError)

    include ClassLoggable

    def self.call(coverage_check)
      new(coverage_check).run_undercover
    end

    attr_reader :coverage_check_id, :run

    def initialize(coverage_check)
      @coverage_check_id = coverage_check.id
      raise RunError, "coverage_reports can't be blank" if coverage_check.coverage_reports.empty?

      # In Rails 6 this will become `coverage_report_jov.coverage_reports.last.open`
      @lcov_tmpfile = Tempfile.new
      @lcov_tmpfile.write(coverage_check.coverage_reports.last.download)
      @lcov_tmpfile.flush

      @run = Hooks::CheckRunInfo.from_coverage_check(coverage_check)
    end

    # TODO: validation and error handling
    def run_undercover
      log "starting run #{run} job_id: #{coverage_check_id}"
      CheckRuns::Run.new(run).post

      clone_repo
      # LOL
      # TODO: checkout correct branch!
      Rugged::Repository.new(repo_path).checkout("origin/test-pr")

      report = run_undercover_cmd

      # TODO: fix reporter to store warnings in state
      warnings = report.build_warnings
      log "undercover warnings: #{warnings.size}"
      # TODO: format undercover results and send with Complete

      log "completing analysis... #{run} job_id: #{coverage_check_id}"
      CheckRuns::Complete.new(run).post(warnings)

      teardown
      log "teardown complete #{run} job_id: #{coverage_check_id}"
    end

    private

    # def validate_run
    #   # TODO: validate if run can be ran:
    #   # - was it queued?
    #   # - lcov present?
    #   # - repo reachable (ls-remote)?
    #   true
    # end

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

    def teardown
      @lcov_tmpfile.close
    end

    def repo_path
      "tmp/job/#{coverage_check_id}"
    end

    def run_undercover_cmd
      opts = Undercover::Options.new.tap do |opt|
        opt.lcov = @lcov_tmpfile.path
        opt.path = repo_path
      end
      changeset = Undercover::Changeset.new("#{repo_path}/.git", "origin/master")
      Undercover::Report.new(changeset, opts).build
    end
  end
end

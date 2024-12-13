# frozen_string_literal: true

module Logic
  class RunUndercover
    include ClassLoggable

    RunError = Class.new(StandardError)
    CheckoutError = Class.new(RunError)
    CloneError = Class.new(RunError)

    def self.call(coverage_check)
      new(coverage_check).run_undercover
    end

    attr_reader :coverage_check, :run

    def initialize(coverage_check)
      @lcov_tmpfile = Tempfile.new
      @coverage_check = coverage_check
      @run = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)
      @changeset = nil

      raise RunError, "coverage_reports can't be blank" if coverage_check.coverage_reports.empty?

      fetch_report
    end

    def run_undercover
      if coverage_check.state != :in_progress
        log "exiting early, coverage_check #{coverage_check.id} is #{coverage_check.state}, but should be in_progress"
        return
      end

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
    rescue Rugged::ReferenceError => e
      cancel_check_and_update_github(e.message)
    ensure
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
      FileUtils.remove_entry(repo_path, true)

      i_token = CheckRuns::InstallationAccessToken.new(run).get
      Git::Clone.perform(
        "https://x-access-token:#{i_token}@github.com/#{run.full_name}.git",
        repo_path,
        "--depth 1 --no-tags"
      )
      Git::Fetch.perform(run.compare, repo_path, "--depth 1 --no-tags") unless run.compare == "HEAD~1"
      Git::Fetch.perform(run.sha, repo_path, "--depth 2 --no-tags")

      list_branches = `cd #{repo_path} && git branch -a`
      crumb = Sentry::Breadcrumb.new(category: "clone_repo", message: list_branches.to_json, level: "info")
      Sentry.add_breadcrumb(crumb)
    rescue Git::GitError => e
      log "clone_repo failed with #{e}"
      raise CloneError
    end

    def checkout
      @repo = Rugged::Repository.new(repo_path)
      branch = @repo.create_branch("undercover-ci", run.sha)
      @repo.checkout(branch)
    rescue Rugged::OSError => e
      log "checkout failed with #{e}"
      raise CheckoutError
    end

    def teardown
      @repo&.close
      @changeset&.instance_variable_get(:@repo)&.close # TODO: hack, expose repo.close through Undercover
      @lcov_tmpfile.close
      FileUtils.remove_entry(repo_path, true)
    end

    def repo_path
      "tmp/job/#{coverage_check.id}"
    end

    def run_undercover_cmd
      opts = Undercover::Options.new.tap do |opt|
        opt.lcov = @lcov_tmpfile.path
        opt.path = repo_path
        opt.glob_reject_filters = %w[test/* spec/* db/* *_test.rb *_spec.rb].freeze
      end
      @changeset = Undercover::Changeset.new("#{repo_path}/.git", @run.compare)
      Undercover::Report.new(@changeset, opts).build
    end

    def cancel_check_and_update_github(message)
      ExpireCheckJob.perform_later(coverage_check.id, message)
    end
  end
end

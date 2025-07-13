# frozen_string_literal: true

module Logic
  class RunUndercover # rubocop:disable Metrics/ClassLength
    include GithubRequests
    include ClassLoggable

    RunError = Class.new(StandardError)
    CheckoutError = Class.new(RunError)
    CloneError = Class.new(RunError)

    def self.call(coverage_check)
      new(coverage_check).run_undercover
    end

    attr_reader :coverage_check, :run

    def initialize(coverage_check)
      @coverage_check = coverage_check
      @run = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)
      @changeset = nil

      raise RunError, "coverage_reports can't be blank" if coverage_check.coverage_reports.empty?

      @coverage_attachment = coverage_check.coverage_reports.last
      @is_json_format = @coverage_attachment.filename.to_s.end_with?(".json")
      @coverage_tmpfile = Tempfile.new

      fetch_report
    end

    def run_undercover
      Logic::UpdateCoverageCheckState.new(coverage_check).start if coverage_check.state == :queued

      if coverage_check.state != :in_progress
        log "exiting early, coverage_check #{coverage_check.id} is #{coverage_check.state}, but should be in_progress"
        return
      end

      log "starting run #{run.external_id} job_id: #{coverage_check.id}"
      CheckRuns::Run.new(run).post

      update_compare_to_merge_base(run)
      clone_repo
      checkout

      report = run_undercover_cmd
      warnings = report.flagged_results
      log "undercover warnings: #{warnings.size}, " \
          "total nodes: #{report.all_results.size}"
      log "completing analysis... #{run.external_id} job_id: #{coverage_check.id}"

      # TODO: improve error handling with transactions
      Logic::SaveResults.call(coverage_check, report)
      run_with_results = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)
      CheckRuns::Complete.new(run_with_results).post(report)
      Logic::UpdateCoverageCheckState.new(coverage_check).complete
    rescue Rugged::ReferenceError => e
      cancel_check_and_update_github(e.message)
    ensure
      teardown
      log "teardown complete #{run.external_id} job_id: #{coverage_check.id}"
    end

    private

    def fetch_report
      # In Rails 6 this will become `coverage_report_jov.coverage_reports.last.open`
      @coverage_tmpfile.write(@coverage_attachment.download)
      @coverage_tmpfile.flush
    end

    def update_compare_to_merge_base(run)
      compare_response = installation_api_client(run.installation_id).compare(run.full_name, run.compare, run.sha)
      merge_base_sha = compare_response.merge_base_commit.sha
      run.compare = merge_base_sha
      log("updated merge base for #{run.external_id} via GitHub compare")
    rescue Octokit::Error => e
      log("update_compare_to_merge_base failed with #{e}, retrying...")
      raise # retry
    end

    # https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/#http-based-git-access-by-an-installation
    def clone_repo
      FileUtils.mkdir_p(repo_path)
      FileUtils.remove_entry(repo_path, true)

      i_token = CheckRuns::InstallationAccessToken.new(run).get
      git = Git.clone("https://x-access-token:#{i_token}@github.com/#{run.full_name}.git", repo_path, depth: 1)

      git.fetch("origin", ref: run.compare, depth: 1) unless run.compare == "HEAD~1"
      git.fetch("origin", ref: run.sha, depth: 2)

      list_branches = `cd #{repo_path} && git branch -a`
      crumb = Sentry::Breadcrumb.new(category: "clone_repo", message: list_branches.to_json, level: "info")
      Sentry.add_breadcrumb(crumb)
    rescue Git::Error => e
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
      @coverage_tmpfile.close
      FileUtils.remove_entry(repo_path, true)
    end

    def repo_path
      "tmp/job/#{coverage_check.id}"
    end

    def run_undercover_cmd
      opts = build_undercover_options
      @changeset = Undercover::Changeset.new("#{repo_path}/.git", @run.compare)
      Undercover::Report.new(@changeset, opts).build
    end

    def build_undercover_options
      opts = Undercover::Options.new
      undercover_config_path = File.join(repo_path, ".undercover")

      config_args = []
      if File.exist?(undercover_config_path)
        log "found .undercover config file, parsing options"
        config_args = opts.__send__(:args_from_options_file, undercover_config_path)
      end
      opts.parse(config_args)

      if @is_json_format
        opts.simplecov_resultset = @coverage_tmpfile.path
        opts.lcov = nil
      else
        opts.simplecov_resultset = nil
        opts.lcov = @coverage_tmpfile.path
      end
      opts.path = repo_path
      opts.compare = @run.compare
      opts.max_warnings_limit = 51
      opts.git_dir = ".git"

      opts
    end

    def cancel_check_and_update_github(message)
      ExpireCheckJob.perform_later(coverage_check.id, message)
    end
  end
end

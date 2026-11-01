# frozen_string_literal: true

require "open3"

module Logic
  class RunUndercover # rubocop:disable Metrics/ClassLength
    include GithubRequests
    include ClassLoggable

    MAX_WARNINGS_LIMIT = 500

    class RunError < StandardError
    end

    class CheckoutError < RunError
    end

    class CloneError < RunError
    end

    class GitError < StandardError
    end

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
      timed(:clone_repo) { clone_repo }
      timed(:checkout) { checkout }

      report = timed(:run_undercover_cmd) { run_undercover_cmd }
      # simplecov:disable
      @changeset.instance_variable_get(:@repo)&.close
      # simplecov:enable
      @changeset = nil
      warnings = report.flagged_results
      log "undercover warnings: #{warnings.size}, " \
          "total nodes: #{report.all_results.size}"
      log "completing analysis... #{run.external_id} job_id: #{coverage_check.id}"

      # TODO: improve error handling with transactions
      Logic::SaveResults.call(coverage_check, report)
      run_with_results = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)
      success = CheckRuns::Complete.new(run_with_results).post(report)
      Logic::UpdateCoverageCheckState.new(coverage_check).complete if success
    rescue Rugged::ReferenceError => e
      cancel_check_and_update_github(e.message)
    ensure
      teardown
      log "teardown complete #{run.external_id} job_id: #{coverage_check.id}"
    end

    private

    def fetch_report
      @coverage_attachment.download { |chunk| @coverage_tmpfile.write(chunk) }
      @coverage_tmpfile.flush
    end

    def update_compare_to_merge_base(run)
      compare_response = installation_api_client(run.installation_id)
                         .compare(run.full_name, url_encode_ref(run.compare), run.sha)
      merge_base_sha = compare_response.merge_base_commit.sha
      run.compare = merge_base_sha
      log("updated merge base for #{run.external_id} via GitHub compare")
    rescue Octokit::Error => e
      log("update_compare_to_merge_base failed with #{e}, retrying...")
      raise # retry
    end

    # A target branch from an upload can hold any character git allows, Octokit's compare doesn't escape it
    def url_encode_ref(ref)
      ref.split("/").map { ERB::Util.url_encode(it) }.join("/")
    end

    # Fetches only the two commits and their trees. File contents are downloaded on demand,
    # so checkout and the diff only pull the files the pull request changed.
    def clone_repo
      FileUtils.remove_entry(repo_path, true)
      FileUtils.mkdir_p(repo_path)

      @token = CheckRuns::InstallationAccessToken.new(run).get
      git("init", "-q")
      git("remote", "add", "origin", remote_url)
      fetch_commits

      crumb = Sentry::Breadcrumb.new(category: "clone_repo", message: [run.compare, run.sha].to_json, level: "info")
      Sentry.add_breadcrumb(crumb)
    rescue GitError => e
      log "clone_repo failed with #{e.message}"
      raise CloneError
    end

    # https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/#http-based-git-access-by-an-installation
    def remote_url
      "https://x-access-token:#{@token}@github.com/#{run.full_name}.git"
    end

    # A fork's head commit is on no branch of the base repo, only on its pull request ref.
    # If that ref has moved on since the upload, the sha is fetched directly.
    def fetch_commits
      fetch = ["fetch", "-q", "--filter=blob:none", "--depth=1", "--no-tags", "origin", run.compare]
      return git(*fetch, run.sha) unless run.pull_request_number

      pull_ref = "refs/remotes/origin/pull/#{run.pull_request_number}"
      git(*fetch, "+refs/pull/#{run.pull_request_number}/head:#{pull_ref}")
      git(*fetch[0...-1], run.sha) unless git("rev-parse", pull_ref).strip == run.sha
    end

    # Writes only the changed files and .undercover to disk. Rugged can't download missing
    # file contents, so the last diff fetches the base side of every changed file in one go.
    def checkout
      # Symlinks become plain files, so a pull request can't point analysis at files outside the checkout
      git("config", "core.symlinks", "false")
      write_sparse_checkout(changed_paths)
      git("checkout", "-q", "-b", "undercover-ci", run.sha)
      git("diff", "--no-renames", "--numstat", run.compare, run.sha)
    rescue GitError => e
      log "checkout failed with #{e.message}"
      raise CheckoutError
    end

    # Compares trees only, so no file contents are needed yet
    def changed_paths
      git("diff", "--name-only", "--no-renames", "-z", run.compare, run.sha).split("\0")
    end

    def write_sparse_checkout(paths)
      git("config", "core.sparseCheckout", "true")
      git("config", "core.sparseCheckoutCone", "false")
      patterns = ["/.undercover", *paths.map { |path| "/#{path.gsub(/[\\*?\[\]!#]/) { "\\#{it}" }}" }]
      File.write(File.join(repo_path, ".git/info/sparse-checkout"), "#{patterns.join("\n")}\n")
    end

    def git(*args)
      out, err, status = Open3.capture3({"GIT_TERMINAL_PROMPT" => "0"}, "git", "-C", repo_path, *args)
      raise GitError, redact("git #{args.first}: #{err.strip}") unless status.success?

      out
    end

    # The token is part of the remote URL, which git may print
    def redact(message)
      message.gsub(@token, "[REDACTED]")
    end

    def timed(step)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield.tap { log "#{step} took #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)}s" }
    end

    def teardown
      # simplecov:disable
      @changeset&.instance_variable_get(:@repo)&.close
      # simplecov:enable
      @coverage_tmpfile.close
      FileUtils.remove_entry(repo_path, true)
      GC.compact
    end

    def repo_path
      "tmp/job/#{coverage_check.id}"
    end

    def run_undercover_cmd
      opts = build_undercover_options
      @changeset = Undercover::Changeset.new("#{repo_path}/.git", run.compare, commits_only: true)
      changed_files = @changeset.file_paths
      simplecov_adapter = if opts.simplecov_resultset
                            Undercover::SimplecovResultAdapter.parse(
                              File.open(opts.simplecov_resultset), opts, only_files: changed_files
                            )
                          else
                            Undercover::LcovParser.parse(
                              File.open(opts.lcov), opts, only_files: changed_files
                            )
                          end
      Undercover::Report.new(@changeset, opts, simplecov_adapter).build
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
      opts.compare = @run.compare
      opts.max_warnings_limit = MAX_WARNINGS_LIMIT

      opts
    end

    def cancel_check_and_update_github(message)
      ExpireCheckJob.perform_later(coverage_check.id, message)
    end
  end
end

# frozen_string_literal: true

module Logic
  # Creates a CoverageCheck for a pull request that never produced a check_suite event,
  # which is the case for pull requests opened from forks. Only trusted when the uploaded
  # sha is the current head of refs/pull/<number>/head in the repo we're installed on.
  class StartCheckRunFromUpload
    include GithubRequests
    include ClassLoggable

    REPO_KEYS = %w[id full_name default_branch visibility private html_url].freeze

    def self.call(repo_full_name, sha, pull_request_number)
      new(repo_full_name, sha, pull_request_number).create_coverage_check
    end

    attr_reader :repo_full_name, :sha, :pull_request_number

    def initialize(repo_full_name, sha, pull_request_number)
      @repo_full_name = repo_full_name
      @sha = sha
      @pull_request_number = pull_request_number.to_i
    end

    def create_coverage_check
      return unless pull_request_number.positive?

      installation = find_installation
      return skip("no installation found for #{repo_full_name}") unless installation
      return skip("fork checks are disabled for #{repo_full_name}") unless enabled?(installation)
      return skip("#{sha} is not the head of #{repo_full_name} pull/#{pull_request_number}") unless
        pull_request_head?(installation)

      repository = fetch_repository(installation)
      return skip("could not fetch #{repo_full_name}") unless repository

      build_coverage_check(installation, repository)
    end

    private

    def build_coverage_check(installation, repository)
      coverage_check = installation.coverage_checks.create!(
        head_sha: sha,
        repo: repository,
        pull_request_number: pull_request_number
      )
      Logic::UpdateCoverageCheckState.new(coverage_check).await_coverage
      log "created CoverageCheck #{coverage_check.id} from upload, " \
          "#{repo_full_name} pull/#{pull_request_number} #{sha}"
      coverage_check
    end

    def find_installation
      Installation.where("repos @> ?", [{full_name: repo_full_name}].to_json).first
    end

    def enabled?(installation)
      installation.fork_checks_enabled?(repo_full_name)
    end

    def pull_request_head?(installation)
      Logic::VerifyPullRequestHead.call(installation.installation_id, repo_full_name, sha, pull_request_number)
    end

    def fetch_repository(installation)
      client(installation).repository(repo_full_name).to_h.transform_keys(&:to_s).slice(*REPO_KEYS)
    rescue Octokit::Error => e
      log "could not fetch #{repo_full_name}: #{e}"
      nil
    end

    def client(installation)
      @client ||= installation_api_client(installation.installation_id)
    end

    def skip(message)
      log "skipping upload-created check, #{message}"
      nil
    end
  end
end

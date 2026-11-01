# frozen_string_literal: true

module Logic
  # Creates a CoverageCheck for a pull request that never produced a check_suite event,
  # which is the case for pull requests opened from forks. Only trusted when the uploaded
  # sha is the current head of refs/pull/<number>/head in the repo we're installed on.
  class StartCheckRunFromUpload
    include GithubRequests
    include ClassLoggable

    REPO_KEYS = %w[id full_name default_branch visibility private html_url].freeze

    def self.call(repo_full_name, sha, pull_request_number, base_ref: nil, head_ref: nil)
      new(repo_full_name, sha, pull_request_number, base_ref:, head_ref:).create_coverage_check
    end

    attr_reader :repo_full_name, :sha, :pull_request_number, :base_ref, :head_ref

    def initialize(repo_full_name, sha, pull_request_number, base_ref: nil, head_ref: nil)
      @repo_full_name = repo_full_name
      @sha = sha
      @pull_request_number = pull_request_number.to_i
      @base_ref = base_ref
      @head_ref = head_ref
    end

    def create_coverage_check
      return unless pull_request_number.positive?

      installation = find_installation
      return skip("#{repo_full_name} is not installed") unless installation
      return skip("#{sha} is not the head of #{repo_full_name} pull/#{pull_request_number}") unless
        pull_request_head?(installation)
      return skip("#{sha} is on a branch excluded by the branch filter") if branch_filtered?(installation)

      repository = fetch_repository(installation)
      return skip("could not fetch #{repo_full_name}") unless repository
      return skip("no active license for private #{repo_full_name}") unless
        repository["visibility"] == "public" || installation.active?

      base_sha = compare_base(installation, repository)
      CoverageCheck.transaction do
        CoverageCheck.lock_repo_sha(repo_full_name, sha)
        CoverageCheck.for_repo_sha(repo_full_name, sha) || build_coverage_check(installation, repository, base_sha)
      end
    end

    private

    def build_coverage_check(installation, repository, base_sha)
      coverage_check = installation.coverage_checks.create!(
        head_sha: sha, repo: repository, pull_request_number:, pull_request_head_ref: head_ref, base_sha:
      )
      Logic::UpdateCoverageCheckState.new(coverage_check).await_coverage
      ExpireCheckJob.set(wait: coverage_check.expire_check_wait).perform_later(coverage_check.id)
      log "created CoverageCheck #{coverage_check.id} from upload, " \
          "#{repo_full_name} pull/#{pull_request_number} #{sha}"
      coverage_check
    end

    # The target branch, which RunUndercover turns into the merge base. A branch the repo doesn't
    # have would fail every compare call, so the check falls back to the default branch instead.
    # Other GitHub errors fail the upload, so a retry compares against the right branch.
    def compare_base(installation, repository)
      return if base_ref.blank?
      return base_ref if base_ref == repository["default_branch"]

      client(installation).get("/repos/#{repo_full_name}/branches/#{base_ref}")
      base_ref
    rescue Octokit::NotFound => e
      log "comparing #{repo_full_name} pull/#{pull_request_number} against the default branch, " \
          "base ref #{base_ref} not found: #{e.class}"
      nil
    end

    # A repo can be listed by a stale installation too, so take the newest one
    def find_installation
      Installation.where("repos @> ?", [{full_name: repo_full_name}].to_json).order(id: :desc).first
    end

    def pull_request_head?(installation)
      Logic::VerifyPullRequestHead.call(installation.installation_id, repo_full_name, sha, pull_request_number)
    end

    # A pull request from a branch of the repo itself has no check when the branch filter skipped
    # its check_suite, so it must not get one through the upload. A fork's head is on no branch.
    def branch_filtered?(installation)
      return false if installation.repo_branch_filters[repo_full_name].blank?

      branches = client(installation).get("/repos/#{repo_full_name}/commits/#{sha}/branches-where-head").map(&:name)
      branches.any? && branches.none? { installation.branch_matches_filter?(it, repo_full_name) }
    rescue Octokit::Error => e
      log "could not list branches of #{sha} in #{repo_full_name}: #{e}"
      true
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

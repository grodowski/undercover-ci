# frozen_string_literal: true

module Logic
  # Confirms that a sha reported by a coverage upload really is the head of the given pull
  # request, which is what makes an unauthenticated upload safe to act on. Reads
  # refs/pull/<number>/head, so it needs no more than the contents permission.
  class VerifyPullRequestHead
    include GithubRequests
    include ClassLoggable

    def self.call(installation_id, repo_full_name, sha, pull_request_number)
      new(installation_id, repo_full_name, sha, pull_request_number).verified?
    end

    attr_reader :installation_id, :repo_full_name, :sha, :pull_request_number

    def initialize(installation_id, repo_full_name, sha, pull_request_number)
      @installation_id = installation_id
      @repo_full_name = repo_full_name
      @sha = sha
      @pull_request_number = pull_request_number.to_i
    end

    def verified?
      ref = installation_api_client(installation_id)
            .get("/repos/#{repo_full_name}/git/ref/pull/#{pull_request_number}/head")
      ref.object.sha == sha
    rescue Octokit::Error => e
      log "could not read pull/#{pull_request_number}/head of #{repo_full_name}: #{e}"
      false
    end
  end
end

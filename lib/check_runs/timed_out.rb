# frozen_string_literal: true

module CheckRuns
  class TimedOut < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "coverage",
        status: "completed",
        started_at: run.created_at, # TODO: update that in this PR
        completed_at: run.last_ts,
        conclusion: "timed_out",
        details_url: details_url,
        external_id: run.external_id,
        output: {title: "Timed Out"},
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end
  end
end

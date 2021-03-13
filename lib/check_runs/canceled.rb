# frozen_string_literal: true

module CheckRuns
  class Canceled < Base
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
        output: {
          title: "Canceled",
          text: text
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    def text
      <<~TEXT
        🤕 This check run was unsuccessful for one of the following reasons:
        - your UndercoverCI subscription has expired
        - no valid coverage data was uploaded within 90 minutes
        - a system error occured

        ⚙️ Visit [the settings page](https://undercover-ci.com/settings) to check your integration
        status.
      TEXT
    end
  end
end

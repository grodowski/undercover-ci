# frozen_string_literal: true

module CheckRuns
  class Run < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "coverage",
        status: "in_progress",
        started_at: run.created_at,
        details_url:,
        external_id: run.external_id,
        output: {
          title: "In progress",
          summary: summary_for_run,
          text: text_for_run
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    private

    def summary_for_run
      "UndercoverCI is running against this commit..."
    end

    def text_for_run
      "⏳"
    end
  end
end

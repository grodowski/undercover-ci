# frozen_string_literal: true

module CheckRuns
  class Create < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "coverage",
        status: "queued",
        started_at: run.created_at,
        details_url:,
        external_id: run.external_id,
        output: {
          title: "Awaiting coverage data",
          summary: queued_text_for_run
        },
        accept: "blah/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    private

    def queued_text_for_run
      <<-TEXT
      ⏳ A coverage fooooo is queued and waiting for your CI to upload a coverage report... If this is
      your first build, take a look at [Undercover CI docs](https://undercover-ci.com/docs).
      TEXT
    end
  end
end

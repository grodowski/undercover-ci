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
        external_id: "", # TODO: set to check database id
        output: {
          title: "Queued",
          summary: "Awaiting coverage data",
          text: queued_text_for_run
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    private

    def queued_text_for_run
      <<-TEXT
      ⏳ A coverage check is queued and waiting for your CI to upload a coverage report...

      📚 If this is your first build, you might want to look at [Undercover CI docs](https://undercover-ci.com/docs).
      TEXT
    end
  end
end

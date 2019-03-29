# frozen_string_literal: true

module CheckRuns
  class Create < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "Coverage Check",
        status: "queued",
        external_id: "", # TODO: create an external id
        output: {
          title: "Waiting for coverage",
          summary: "Undercover CI is awaiting a coverage report...",
          text: "**TODO: LCOV coverage setup instructions**\n\n```\ndef hello\n  $$$\nend\n```\n~~hello~~"
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end
  end
end

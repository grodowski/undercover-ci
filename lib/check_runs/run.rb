# frozen_string_literal: true

module CheckRuns
  class Run < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "Coverage Check",
        status: "in_progress",
        started_at: Time.now.iso8601,
        external_id: "", # TODO: create an external id
        output: {
          title: "Analysing coverage report",
          summary: "Undercover CI run is in progress...",
          text: "**TODO: add something nice**\n\n```\ndef hello\n  $$$\nend\n```\n~~hello~~"
        },
        headers: {"Accept": "application/vnd.github.antiope-preview+json"}
      )
      Rails.logger.debug(client.last_response)
    end
  end
end

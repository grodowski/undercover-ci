# frozen_string_literal: true

module CheckRuns
  class Create < Base
    def post
      installation_api_client(run.installation_id).post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "Coverage Check",
        status: "queued",
        started_at: Time.now.iso8601,
        external_id: "", # TODO: create an external id
        output: {
          title: "Waiting for coverage",
          summary: "Undercover CI is awaiting a coverage report...",
          text: "**TODO: LCOV coverage setup instructions**\n\n```\ndef hello\n  $$$\nend\n```\n~~hello~~"
        },
        headers: {"Accept": "application/vnd.github.antiope-preview+json"}
      )
      # TODO: check response
    end
  end
end

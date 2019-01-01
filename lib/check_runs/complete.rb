# frozen_string_literal: true

module CheckRuns
  class Complete < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "Coverage Check",
        status: "completed",
        # TODO: send started_at
        completed_at: Time.now.iso8601,
        conclusion: "failure",
        details_url: "https://google.com",
        external_id: "", # TODO: create an external id
        output: {
          title: "Analysing coverage report",
          summary: "Undercover CI run is in progress...",
          text: "**TODO: add something nice**\n\n```\ndef hello\n  $$$\nend\n```\n~~hello~~"
        },
        annotations: [
          {
            path: "lib/undercover.rb",
            start_line: 38,
            end_line: 39,
            annotation_level: "warning",
            title: "Insufficient Test Coverage",
            message: "Instance method `test_method` is missing coverage for line 39 (method coverage: 0.0%)"
          }
        ],
        accept: "application/vnd.github.antiope-preview+json"
      )
      Rails.logger.debug("CheckRuns::Complete response: #{client.last_response.status}")
    end
  end
end

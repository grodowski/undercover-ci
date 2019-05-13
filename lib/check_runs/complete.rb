# frozen_string_literal: true

module CheckRuns
  class Complete < Base
    # @param undercover_warnings [Array] list of warnings reported by Undercover
    def post(undercover_warnings)
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "Coverage Check",
        status: "completed",
        # started_at: "", # TODO: store started at
        completed_at: Time.now.iso8601,
        conclusion: "failure",
        details_url: "https://google.com",
        external_id: "", # TODO: create an external id
        output: {
          title: "Code coverage report",
          summary: summary_for_run(undercover_warnings),
          text: text_for_run(undercover_warnings),
          annotations: warnings_to_annotations(undercover_warnings)
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    private

    # @return [Array] matching the format expected by GitHub Checks API
    # https://developer.github.com/v3/checks/runs/#output-object
    def warnings_to_annotations(undercover_results)
      log "posting warnings: #{undercover_results}"
      undercover_results.map do |result|
        # TODO: duplicates pronto-undercover logic, move to Undercover::Result
        lines = result.coverage.map { |ln, _cov| ln if result.uncovered?(ln) }.compact
        message = "#{result.node.human_name.capitalize} `#{result.node.name}` is missing" \
                  " coverage for line#{'s' if lines.size > 1} #{lines.join(', ')}" \
                  " (node coverage: #{result.coverage_f})"
        {
          path: "app/models/application_record.rb",
          start_line: result.first_line,
          end_line: result.last_line,
          annotation_level: "warning",
          title: "FOO",
          message: message
        }
      end
    end

    # TODO: conditional copy
    # - if no warnings, tell that it's a clean PR!
    # - if warnings present, suggest to add test coverage
    # - show some stats
    #   - num methods / classes / changed / added / removed
    #   - avg coverage per method
    # - show a random tip

    # TODO: failure / aborted check run copy
    def summary_for_run(_warnings)
      nil
    end

    def text_for_run(_warnings)
      nil
    end
  end
end

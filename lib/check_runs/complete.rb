# frozen_string_literal: true

module CheckRuns
  class Complete < Base
    # @param undercover_warnings [Array] list of warnings reported by Undercover
    def post(undercover_warnings)
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "coverage",
        status: "completed",
        started_at: run.created_at,
        completed_at: run.last_ts,
        conclusion: conclusion_for_run(undercover_warnings),
        details_url: details_url,
        external_id: run.external_id,
        output: {
          title: "Complete",
          summary: summary_for_run,
          text: text_for_run(undercover_warnings),
          annotations: warnings_to_annotations(undercover_warnings)
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    # TODO: deserves to be moved elswhere
    def format_lines(lines)
      prev = lines[0]
      slices = lines.slice_before do |e|
        (prev + 1 != e).tap { prev = e }
      end
      slices.map { |slice_first, *, slice_last| slice_last ? (slice_first..slice_last) : slice_first }
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
                  " coverage for line#{'s' if lines.size > 1} #{format_lines(lines).join(',')}" \
                  " (node coverage: #{result.coverage_f})"
        {
          path: result.file_path,
          start_line: result.first_line,
          end_line: result.last_line,
          annotation_level: "warning",
          title: "Untested #{result.node.human_name}",
          message: message
        }
      end
    end

    def conclusion_for_run(warnings)
      warnings.empty? ? "success" : "failure"
    end

    def summary_for_run
      complete_message = run.num_warnings.zero? ? "🚀 Ship it!" : "🚨"
      num = ActionController::Base.helpers.pluralize(run.num_warnings, "warning")
      "#{complete_message} Undercover CI has detected #{num} in this changeset."
    end

    # TODO: ideas
    # - show some stats
    #   - num methods / classes / changed / added / removed
    #   - avg coverage per method
    # - show a random tip
    def text_for_run(_warnings)
      "" # TODO: complete text_for_run
    end
  end
end

# frozen_string_literal: true

module CheckRuns
  class Complete < Base
    # @param undercover_warnings [Array] list of warnings reported by Undercover
    def post(undercover_report)
      @undercover_report = undercover_report
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "coverage",
        status: "completed",
        started_at: run.created_at,
        completed_at: run.last_ts,
        conclusion: conclusion_for_run,
        details_url: details_url,
        external_id: run.external_id,
        output: {
          title: "Complete",
          summary: summary_for_run,
          text: text_for_run,
          annotations: warnings_to_annotations
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

    # TODO: can be updated to read directly from `run.nodes` instead of passing `undercover_report`
    # @return [Array] matching the format expected by GitHub Checks API
    # https://developer.github.com/v3/checks/runs/#output-object
    def warnings_to_annotations
      results = @undercover_report.flagged_results
      log "posting warnings: #{results}"
      results.map do |result|
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

    def conclusion_for_run
      run.success? ? "success" : "failure"
    end

    def summary_for_run
      complete_message = run.num_warnings.zero? ? "🚀 Ship it!" : "🚨"
      num = ActionController::Base.helpers.pluralize(run.num_warnings, "warning")
      "#{complete_message} Undercover CI has detected #{num} in this changeset."
    end

    def text_for_run
      text = "Revision `#{run.sha[0..5]}` has modified the following " \
        "#{ActionController::Base.helpers.pluralize(@undercover_report.all_results.size, 'code location')}."
      if @run.nodes.select(&:flagged?).any?
        text += " Results marked with ⚠️ have untested lines added or changed in this commit, " \
                "look into them!"
      end
      text += "\n\n"
      rows = ["name | coverage", ":--- | ---:"]
      format_to_md = proc do |node|
        flag = node.flagged? ? "⚠️ " : ""
        ["#{flag}#{node.node_type} `#{node.node_name}`", node.coverage]
      end
      rows += @run
              .nodes
              .sort_by { |node| node.flagged? ? 0 : 1 }
              .map(&format_to_md)
              .map { |row| row.join(" | ") }
      text + rows.join("\n")
    end
  end
end

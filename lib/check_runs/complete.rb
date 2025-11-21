# frozen_string_literal: true

module CheckRuns
  class Complete < Base # rubocop:disable Metrics/ClassLength
    # Prevents GitHub Checks API errors with the 50 annotation limit
    # https://docs.github.com/en/rest/checks/runs?apiVersion=2022-11-28#update-a-check-run--parameters
    MAX_ANNOTATIONS = 50
    DEFAULT_FAILURE_MODE = "failure"

    # @param undercover_warnings [Array] list of warnings reported by Undercover
    def post(undercover_report)
      tries = 0
      retry_limit = 2
      begin
        tries += 1
        @undercover_report = undercover_report
        @warnings = undercover_report.flagged_results
        client = installation_api_client(run.installation_id)
        client.post(
          "/repos/#{run.full_name}/check-runs",
          head_sha: run.sha,
          name: "coverage",
          status: "completed",
          started_at: run.created_at,
          completed_at: run.last_ts,
          conclusion: conclusion_for_run,
          details_url:,
          external_id: run.external_id,
          output: {
            title: "Complete",
            summary: summary_for_run,
            text: text_for_run,
            annotations: warnings_to_annotations.first(MAX_ANNOTATIONS)
          },
          accept: "application/vnd.github.antiope-preview+json"
        )
        log "#{run.external_id} response: #{client.last_response.status}"
      rescue Octokit::UnprocessableEntity, Octokit::InternalServerError => e
        retry if tries <= retry_limit

        error_message = if e.message.include?("Only 65535 characters are allowed")
                          "The check output exceeded GitHub's character limit, please inspect " \
                            "the UndercoverCI dashboard directly"
                        elsif e.is_a?(Octokit::InternalServerError)
                          "500 - Something went wrong"
                        else
                          e.message
                        end
        log("Check completion #{run.external_id} failed with #{error_message}, expiring...")
        if e.is_a?(Octokit::InternalServerError)
          Sentry.capture_exception(e) do |scope|
            scope.set_context("status", client.last_response.status)
            scope.set_context("headers", client.last_response.headers)
          end
        end
        ExpireCheckJob.perform_later(run.external_id, error_message)
      end
    end

    # TODO: deserves to be moved elswhere
    def format_lines(lines)
      prev = lines.first
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
      log "posting warnings: #{@warnings.size}"
      @warnings.map do |result|
        # TODO: duplicates pronto-undercover logic, move to Undercover::Result
        lines = result.coverage.map { |ln, *| ln if result.uncovered?(ln) }.compact.uniq
        message = "#{result.node.human_name.capitalize} `#{result.node.name}` is missing " \
                  "coverage for line#{'s' if lines.size > 1} #{format_lines(lines).join(',')} " \
                  "(node coverage: #{result.coverage_f})."

        lines_missing_branch_cov = result.coverage.map do |ln, _block, _branch, cov|
          ln if cov&.zero?
        end.compact.uniq
        if lines_missing_branch_cov.any?
          message += "\nMissing branch coverage found in line#{'s' if lines_missing_branch_cov.size > 1} " \
                     "#{format_lines(lines_missing_branch_cov).join(',')}."
        end
        {
          path: result.file_path,
          start_line: result.first_line,
          end_line: result.last_line,
          annotation_level: "warning",
          title: "Untested #{result.node.human_name}",
          message:,
          raw_details: result.pretty_print
        }
      end
    end

    def conclusion_for_run
      failure_mode = run.failure_mode || DEFAULT_FAILURE_MODE
      run.success? ? "success" : failure_mode
    end

    def summary_for_run
      complete_message = run.num_warnings.zero? ? "🚀 Ship it!" : "🚨"
      num = ActionController::Base.helpers.pluralize(run.num_warnings, "warning")
      "#{complete_message} UndercoverCI has detected #{num} in this changeset."
    end

    def text_for_run
      text = "Revision `#{run.sha[0..6]}` has modified the following " \
             "#{ActionController::Base.helpers.pluralize(@undercover_report.all_results.size, 'code location')}."
      if @run.nodes.any?(&:flagged?)
        text += " Results marked with ⚠️ have untested lines added or changed in this commit, " \
                "look into them!"
      end
      if @warnings.size > MAX_ANNOTATIONS
        text += "\n\n"
        text += "⚠️ Due to GitHub's 50 annotation limit, only the first 50 warnings are shown in the pull request " \
                "diff. Please inspect the table below and the full report at #{details_url}."
      end
      text += "\n\n"
      rows = ["file | name | coverage | branches", ":--- | :--- | ---: | ---:"]
      format_to_md = proc do |node|
        flag = node.flagged? ? "⚠️ " : ""
        [
          node.path,
          "#{flag}#{node.node_type} `#{node.node_name}`",
          node.coverage,
          total_branches_for_node(node)
        ]
      end
      rows += @run
              .nodes
              .sort_by { |node| node.flagged? ? 0 : 1 }
              .map(&format_to_md)
              .map { |row| row.join(" | ") }
      text + rows.join("\n")
    end

    # TODO: read directly from node and not @undercover_report
    def total_branches_for_node(node)
      result = @warnings.find do |res|
        res.file_path == node.path && res.first_line == node.start_line && res.node.name == node.node_name
      end
      return unless result

      branches = result.coverage.select { |cov| cov.size == 4 } # BRDA branch
      count_covered = branches.count { |cov| cov[3].positive? } # was that branch covered?

      "#{count_covered}/#{branches.size}"
    end
  end
end

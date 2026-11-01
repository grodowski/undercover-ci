# frozen_string_literal: true

module CheckRuns
  class Complete < Base # rubocop:disable Metrics/ClassLength
    # Prevents GitHub Checks API errors with the 50 annotation limit
    # https://docs.github.com/en/rest/checks/runs?apiVersion=2022-11-28#update-a-check-run--parameters
    MAX_ANNOTATIONS = 50
    MAX_TABLE_ROWS = 100
    MAX_SKIPPED_PATHS = 3
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
        true
      rescue Octokit::UnprocessableEntity, Octokit::InternalServerError => e
        retry if tries <= retry_limit

        error_message = if e.message.include?("Only 65535 characters are allowed")
                          "The check output exceeded GitHub's character limit, please inspect " \
                            "the UndercoverCI dashboard directly"
                        elsif e.is_a?(Octokit::InternalServerError)
                          "The check result failed to submit due to a service error (500)"
                        else
                          e.message
                        end
        log("Check completion #{run.external_id} failed with #{error_message}, expiring...")
        if e.is_a?(Octokit::InternalServerError)
          Sentry.capture_exception(e) do |scope|
            scope.set_extras(
              {
                response_status: client.last_response.status,
                response_headers: client.last_response.headers
              }
            )
          end
        end
        ExpireCheckJob.perform_later(run.external_id, error_message)
        false
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
          annotation_level: run.critical?(result.file_path) ? "failure" : "warning",
          title: "Untested #{result.node.human_name}",
          message:,
          raw_details: result.pretty_print
        }
      end
    end

    def conclusion_for_run
      return "success" if run.success?
      return "failure" if run.critical_warnings.any?

      run.failure_mode || DEFAULT_FAILURE_MODE
    end

    def summary_for_run
      complete_message = run.num_warnings.zero? ? "🚀 Ship it!" : "🚨"
      num = pluralize(run.num_warnings, "warning")
      summary = "#{complete_message} UndercoverCI has detected #{num} in this changeset"
      summary += ", #{run.critical_warnings.size} in critical paths" if run.critical_warnings.any?
      summary += "."
      summary += " ⚠️ Analysis stopped after #{num}, see the details below." if warnings_limit_hit?
      summary += " ℹ️ Some changed files were not checked, see the details below." if skipped_files_notes.any?
      summary
    end

    def full_list_location
      report = "the full report at #{details_url}"
      @warnings.size <= MAX_TABLE_ROWS ? "the table below and #{report}" : report
    end

    def warnings_limit_hit?
      @warnings.size >= Logic::RunUndercover::MAX_WARNINGS_LIMIT
    end

    def skipped_files_notes
      @skipped_files_notes ||= [
        skipped_files_note(@undercover_report.erb_files_without_coverage) do |count|
          "Skipped #{pluralize(count, 'ERB template')}: the coverage report has no ERB coverage. " \
            "Add `enable_coverage(:eval)` to `SimpleCov.start` to check them."
        end,
        skipped_files_note(@undercover_report.erb_parse_failures) do |count|
          "Skipped #{pluralize(count, 'ERB template')} that could not be parsed."
        end,
        skipped_files_note(globbed_out_files_when_nothing_checked) do |count|
          "No changed files were checked. The include/exclude globs (`--include-files`/`--exclude-files`) " \
            "excluded #{pluralize(count, 'changed file')}. " \
            "Globs are matched relative to the directory SimpleCov covered."
        end
      ].compact
    end

    def skipped_files_note(paths)
      return if paths.empty?

      lines = paths.first(MAX_SKIPPED_PATHS).map { |path| "- `#{path}`" }
      lines << "- and #{paths.size - MAX_SKIPPED_PATHS} more" if paths.size > MAX_SKIPPED_PATHS
      "ℹ️ #{yield(paths.size)}\n#{lines.join("\n")}"
    end

    # Lockfiles, docs and specs are rejected on every PR; only Ruby code undercover would check by default
    # hints at misconfigured globs, e.g. a monorepo app path repeated in them
    def globbed_out_files_when_nothing_checked
      return [] unless @undercover_report.all_results.empty?

      @undercover_report.globbed_out_files.select { |path| checked_by_default_globs?(path) }
    end

    def checked_by_default_globs?(path)
      Undercover::Options::DEFAULT_FILE_INCLUDE_GLOBS.any? { |glob| File.fnmatch(glob, File.basename(path)) } &&
        Undercover::Options::DEFAULT_FILE_EXCLUDE_GLOBS.none? { |glob| File.fnmatch(glob, path) }
    end

    def pluralize(count, word)
      ActionController::Base.helpers.pluralize(count, word)
    end

    def text_for_run
      text = "Revision `#{run.sha[0..6]}` has modified the following " \
             "#{ActionController::Base.helpers.pluralize(@undercover_report.all_results.size, 'code location')}."
      if @run.nodes.flagged.exists?
        text += " Results marked with ⚠️ have untested lines added or changed in this commit, " \
                "look into them!"
      end
      text += " Warnings marked (critical) match a critical path and fail the check." if run.critical_warnings.any?
      if warnings_limit_hit?
        text += "\n\n⚠️ Analysis stopped after #{pluralize(@warnings.size, 'warning')}, so the rest of the diff " \
                "was not checked."
      end
      if @warnings.size > MAX_ANNOTATIONS
        text += "\n\n⚠️ Found #{pluralize(@warnings.size, 'warning')}. GitHub allows #{MAX_ANNOTATIONS} annotations " \
                "per check, so the first #{MAX_ANNOTATIONS} are annotated in the pull request diff. " \
                "All #{@warnings.size} are in #{full_list_location}."
      end
      skipped_files_notes.each { |note| text += "\n\n#{note}" }
      text += "\n\n"
      rows = ["file | name | coverage | branches", ":--- | :--- | ---: | ---:"]
      format_to_md = proc do |node|
        flag = node.flagged? ? "⚠️ " : ""
        critical = " (critical)" if node.flagged? && run.critical?(node.path)
        [
          node.path,
          "#{flag}#{node.node_type} `#{node.node_name}`#{critical}",
          node.coverage,
          total_branches_for_node(node)
        ]
      end
      all_nodes = @run.nodes.order(flagged: :desc).first(MAX_TABLE_ROWS + 1)
      truncated = all_nodes.size > MAX_TABLE_ROWS
      rows += all_nodes.first(MAX_TABLE_ROWS).map(&format_to_md).map { |row| row.join(" | ") }
      if truncated
        text += "\n\n_Showing the first #{MAX_TABLE_ROWS} results. " \
                "See the [full report](#{details_url}) for the complete list._"
      end
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

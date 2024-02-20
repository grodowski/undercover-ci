# frozen_string_literal: true

module CheckRuns
  class Canceled < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "coverage",
        status: "completed",
        started_at: run.created_at, # TODO: update that in this PR
        completed_at: run.last_ts,
        conclusion: "cancelled",
        details_url:,
        external_id: run.external_id,
        output: {
          title:,
          summary:
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    private

    def db_check
      @db_check ||= CoverageCheck.find(run.external_id)
    end

    def license_expired?
      !db_check.installation.active?
    end

    def no_coverage?
      db_check.coverage_reports.empty?
    end

    def error?
      run.error_message.present?
    end

    def title
      return "License expired" if license_expired?
      return "Service error" if error?
      return "Timed out waiting for coverage data" if no_coverage?

      "Check run unsuccessful"
    end

    def summary
      return text_error if error?

      license_expired? ? text_expired : text_generic
    end

    def text_error
      "🤕 An error occured while processing this commit: `#{run.error_message}`."
    end

    def text_expired
      "🔐 Your UndercoverCI license has expired, visit [settings](https://undercover-ci.com/settings) to subscribe."
    end

    def text_generic
      <<~TEXT
        🤕 This check run was unsuccessful for one of the following reasons:
        - no valid coverage data was uploaded within 90 minutes
        - a system error occured

        ⚙️ Check your integration [settings](https://undercover-ci.com/settings).
      TEXT
    end
  end
end

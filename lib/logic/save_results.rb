# frozen_string_literal: true

module Logic
  class SaveResults
    def self.call(coverage_check, report)
      new(coverage_check, report).call
    end

    def initialize(coverage_check, report)
      @coverage_check = coverage_check
      @all_results = report.all_results
    end

    def call
      flagged = false
      rows = all_results.map do |result|
        flagged = true if result.flagged?
        {
          coverage_check_id: coverage_check.id,
          path: result.file_path,
          node_type: result.node.human_name,
          node_name: result.node.name,
          start_line: result.first_line,
          end_line: result.last_line,
          coverage: result.coverage_f,
          flagged: result.flagged?,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      Node.insert_all(rows) if rows.any?
      coverage_check.update!(result: flagged ? "failed" : "passed")
    end

    private

    attr_reader :coverage_check, :all_results
  end
end

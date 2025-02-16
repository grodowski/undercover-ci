# frozen_string_literal: true

module Logic
  class SaveResults
    def self.call(coverage_check, report)
      new(coverage_check, report).call
    end

    def initialize(coverage_check, report)
      @coverage_check = coverage_check
      @all_results = report.all_results.to_a
    end

    def call
      all_results.each { |result| build_node(result) }
      coverage_check.update!(result: build_result)
    end

    private

    def build_result
      all_results.any?(&:flagged?) ? "failed" : "passed"
    end

    def build_node(node_result)
      coverage_check.nodes << Node.new(
        path: node_result.file_path,
        node_type: node_result.node.human_name,
        node_name: node_result.node.name,
        start_line: node_result.first_line,
        end_line: node_result.last_line,
        coverage: node_result.coverage_f,
        flagged: node_result.flagged?
      )
    end

    attr_reader :coverage_check, :all_results
  end
end

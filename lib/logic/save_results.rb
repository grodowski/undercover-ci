# frozen_string_literal: true

module Logic
  class SaveResults
    def self.call(coverage_check, report, warnings)
      new(coverage_check, report, warnings).call
    end

    def initialize(coverage_check, report, warnings)
      @coverage_check = coverage_check
      # all_results = report.all_results | warnings.to_a
      all_results = warnings.to_a
      flagged = all_results.map { |r| warnings.include?(r) }
      @all_results_with_flagged = all_results.zip(flagged)
    end

    def call
      all_results_with_flagged.each { |r_tuple| build_node(*r_tuple) }
      coverage_check.save!
    end

    private

    def build_node(node_result, flagged)
      coverage_check.nodes << Node.new(
        path: node_result.file_path,
        node_type: node_result.node.human_name,
        node_name: node_result.node.name,
        start_line: node_result.first_line,
        end_line: node_result.last_line,
        coverage: node_result.coverage_f,
        flagged: flagged
      )
    end

    attr_reader :coverage_check, :all_results_with_flagged
  end
end

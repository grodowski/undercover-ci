# frozen_string_literal: true

module Logic
  class MergeOutcomes
    class Report
      PERIODS = {7 => "the last week", 14 => "the last 2 weeks", 30 => "the last 30 days"}.freeze

      attr_reader :result

      def initialize(result)
        @result = result
      end

      def installation = result.installation
      def days = result.days
      def current = result.current
      def account = result.account

      def notable?
        current.pull_requests.any?
      end

      def to_s
        "#{header}\n\nSubject: #{subject}\n\n#{body}\n"
      end

      def header
        unresolved = current.count(:unresolved)
        note = " · #{prs(unresolved)} not resolved on GitHub" if unresolved.positive?
        "=== #{account} (installation #{installation.installation_id}) · #{days} days#{note} ==="
      end

      def subject
        "Your UndercoverCI stats for #{period}"
      end

      def body
        [
          "Hey #{account},",
          "",
          "here are your UndercoverCI stats for #{period}:",
          "",
          *stats_lines,
          "",
          "Do you find this useful? I'm researching more advanced coverage reporting views for UndercoverCI " \
          "and I'm curious to learn what else you'd like to see.",
          "",
          "Jan"
        ].join("\n")
      end

      private

      def period = PERIODS[days]

      def prs(count) = "#{count} #{'pull request'.pluralize(count)}"

      def stats_lines
        lines = []
        if current.caught_count.positive?
          lines << "- #{current.caught_count} went from red to green: UndercoverCI flagged untested code " \
                   "and the tests were added before merging"
        end
        lines << "- #{prs(current.pull_requests.size)} merged"
        lines << "- #{current.count(:passed)} fully tested when they merged" if current.count(:passed).positive?
        lines.concat(untested_lines)
        {
          merged_before_check: "merged before the coverage check finished",
          no_coverage: "merged without a coverage result",
          no_check: "merged without a coverage check"
        }.each { |outcome, text| lines << "- #{current.count(outcome)} #{text}" if current.count(outcome).positive? }
        lines
      end

      def untested_lines
        with_warnings = current.with_warnings.sort_by { [it.repo, it.number] }
        return [] if with_warnings.empty?

        lines = ["- #{with_warnings.size} merged with untested code:"]
        with_warnings.each do |pr|
          names = pr.flagged_nodes.map { it[:name] == "block" ? "block in #{it[:path]}" : it[:name] }.uniq
          details = " (#{names.join(', ')})" if names.any?
          lines << "  - https://github.com/#{pr.repo}/pull/#{pr.number}#{details}"
        end
        lines
      end
    end
  end
end

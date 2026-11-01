# frozen_string_literal: true

module Logic
  class MergeOutcomes # rubocop:disable Metrics/ClassLength
    include GithubRequests
    include ClassLoggable

    DAYS = [7, 14, 30].freeze
    PR_CHECK_PADDING = 14.days
    OUTCOMES = %i[passed merged_with_warnings merged_before_check no_coverage no_check unresolved].freeze
    MERGE_COMMIT = /\AMerge pull request #(\d+)/
    SQUASH_COMMIT = /\(#(\d+)\)\s*\z/
    FLAGGED_NODES_PER_PR = 3

    Check = Data.define(:id, :repo, :number, :head_sha, :created_at, :state, :warnings, :completed_at)
    PullRequest = Data.define(:repo, :number, :merged_at, :check_id, :outcome, :caught, :flagged_nodes)

    Window = Data.define(:from, :to, :pull_requests, :pushes_without_pr) do
      def count(outcome) = pull_requests.count { it.outcome == outcome }
      def caught_count = pull_requests.count(&:caught)
      def with_warnings = pull_requests.select { it.outcome == :merged_with_warnings }
    end

    Result = Data.define(:installation, :days, :current, :previous) do
      def account = installation.metadata&.dig("account", "login") || installation.installation_id.to_s
    end

    def self.call(installation, days: DAYS.first, now: Time.current)
      new(installation, days:, now:).call
    end

    def self.validate_days!(days)
      return days if DAYS.include?(days)

      raise ArgumentError, "DAYS must be one of #{DAYS.join(', ')}"
    end

    def self.pr_number(message)
      subject = message.to_s.lines.first.to_s
      match = MERGE_COMMIT.match(subject) || SQUASH_COMMIT.match(subject)
      match && match[1].to_i
    end

    def self.default_branch_checks(from, to)
      CoverageCheck
        .where("coverage_checks.check_suite->>'head_branch' = coverage_checks.repo->>'default_branch'")
        .where(created_at: (from - 1.day)..(to + 1.day))
        .where("(coverage_checks.check_suite->'head_commit'->>'timestamp')::timestamptz >= ?", from)
        .where("(coverage_checks.check_suite->'head_commit'->>'timestamp')::timestamptz < ?", to)
    end

    def self.installations_with_merges(days, now: Time.current)
      Installation.where(id: default_branch_checks(now - days.days, now).select(:installation_id)).order(:id)
    end

    attr_reader :installation, :days, :now

    def initialize(installation, days: DAYS.first, now: Time.current)
      @installation = installation
      @days = self.class.validate_days!(days)
      @now = now
    end

    def call
      current_from = now - days.days
      previous_from = current_from - days.days
      merges, pushes = load_merges(previous_from)
      pull_requests = resolve(merges, load_pr_checks(previous_from - PR_CHECK_PADDING, merges.keys.map(&:first).uniq))

      Result.new(
        installation:, days:,
        current: window(current_from, now, pull_requests, pushes, flagged_nodes: true),
        previous: window(previous_from, current_from, pull_requests, pushes)
      )
    end

    private

    def window(from, to, pull_requests, pushes, flagged_nodes: false)
      in_window = ->(time) { time >= from && time < to }
      prs = pull_requests.select { in_window.call(it.merged_at) }
      prs = with_flagged_nodes(prs) if flagged_nodes
      pushes_without_pr = pushes.select { in_window.call(it.last) }.map(&:first).tally
      Window.new(from:, to:, pull_requests: prs, pushes_without_pr:)
    end

    def load_merges(from)
      merges = {}
      pushes = []
      self.class.default_branch_checks(from, now).where(installation_id: installation.id)
          .pluck(Arel.sql("repo->>'full_name'"), Arel.sql("check_suite->'head_commit'->>'message'"),
                 Arel.sql("(check_suite->'head_commit'->>'timestamp')::timestamptz"))
          .each do |repo, message, merged_at|
            number = self.class.pr_number(message)
            next pushes << [repo, merged_at] unless number

            key = [repo, number]
            merges[key] = merged_at if merges[key].nil? || merged_at < merges[key]
          end
      [merges, pushes]
    end

    def resolve(merges, pr_checks)
      checks_by_pr = pr_checks.group_by { [it.repo, it.number] }
      heads = merges.to_h { |key, merged_at| [key, latest_before(checks_by_pr.fetch(key, []), merged_at)] }
      shas = merges.keys.reject { heads[it] }.index_with { |(repo, number)| ref_head_sha(repo, number) }
      checks_by_sha = load_checks_by_sha(shas.values.grep(String))

      merges.filter_map do |key, merged_at|
        sha = shas[key]
        next if sha == :not_a_pr

        head = heads[key] || latest_before(checks_by_sha.fetch(sha, []), merged_at)
        outcome = sha == :unresolved ? :unresolved : outcome(head, merged_at)
        PullRequest.new(
          repo: key.first, number: key.last, merged_at:, check_id: head&.id, outcome:,
          caught: caught?(outcome, head, checks_by_pr.fetch(key, [])), flagged_nodes: []
        )
      end
    end

    def latest_before(checks, time)
      checks.select { it.created_at <= time }.max_by(&:created_at)
    end

    def outcome(check, merged_at)
      return :no_check unless check
      return :no_coverage if check.state == "canceled"
      return :merged_before_check unless check.state == "complete"
      return :merged_before_check if check.completed_at && check.completed_at > merged_at

      check.warnings ? :merged_with_warnings : :passed
    end

    def caught?(outcome, head, pr_checks)
      outcome == :passed &&
        pr_checks.any? { it.created_at < head.created_at && it.state == "complete" && it.warnings }
    end

    def ref_head_sha(repo, number)
      return :unresolved unless api_client

      api_client.get("/repos/#{repo}/git/ref/pull/#{number}/head").object.sha
    rescue Octokit::NotFound
      :not_a_pr
    rescue Octokit::Error, Faraday::Error => e
      log "could not read pull/#{number}/head of #{repo}: #{e.class} #{e.message}"
      :unresolved
    end

    def api_client
      return @api_client if defined?(@api_client)

      @api_client = installation_api_client(installation.installation_id)
    rescue Octokit::Error, Faraday::Error => e
      log "could not create a client for installation #{installation.installation_id}: #{e.class} #{e.message}"
      @api_client = nil
    end

    def check_columns(number_sql)
      [
        "coverage_checks.id",
        "coverage_checks.repo->>'full_name'",
        number_sql,
        "coverage_checks.head_sha",
        "coverage_checks.created_at",
        "coverage_checks.state",
        "COALESCE(coverage_checks.result = 'failed', EXISTS (SELECT 1 FROM nodes " \
        "WHERE nodes.coverage_check_id = coverage_checks.id AND nodes.flagged))",
        "(SELECT MIN((log->>'ts')::timestamptz) FROM jsonb_array_elements(coverage_checks.state_log) log " \
        "WHERE log->>'to' = 'complete')"
      ].map { Arel.sql(it) }
    end

    def load_pr_checks(from, repos)
      return [] if repos.empty?

      CoverageCheck
        .joins("CROSS JOIN LATERAL jsonb_array_elements(" \
               "COALESCE(coverage_checks.check_suite->'pull_requests', '[]'::jsonb)) pull_request")
        .where(installation_id: installation.id, created_at: from..now)
        .where("coverage_checks.repo->>'full_name' IN (?)", repos)
        .pluck(*check_columns("(pull_request->>'number')::int"))
        .map { Check.new(*it) }
    end

    def load_checks_by_sha(shas)
      return {} if shas.empty?

      CoverageCheck.where(installation_id: installation.id, head_sha: shas)
                   .pluck(*check_columns("NULL")).map { Check.new(*it) }.group_by(&:head_sha)
    end

    def with_flagged_nodes(pull_requests)
      check_ids = pull_requests.select { it.outcome == :merged_with_warnings }.map(&:check_id)
      return pull_requests if check_ids.empty?

      ranked = Node.where(coverage_check_id: check_ids, flagged: true)
                   .select(:coverage_check_id, :path, :node_type, :node_name, :id,
                           "ROW_NUMBER() OVER (PARTITION BY coverage_check_id ORDER BY id) AS position")
      nodes = Node.from(ranked, :nodes).where(position: ..FLAGGED_NODES_PER_PR).order(:coverage_check_id, :id)
                  .pluck(:coverage_check_id, :node_type, :node_name, :path).group_by(&:first)
      pull_requests.map do |pr|
        pr.with(flagged_nodes: nodes.fetch(pr.check_id, []).map { |_, type, name, path| {type:, name:, path:} })
      end
    end
  end
end

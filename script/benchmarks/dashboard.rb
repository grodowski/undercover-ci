# frozen_string_literal: true

# Times the dashboard requests for the user seeded by script/benchmarks/seed_dashboard.rb, with the
# GitHub installations sync stubbed out, and breaks them down per SQL query.
#
#   DATABASE_URL=postgres://postgres@localhost/undercover-ci_benchmark bin/rails runner script/benchmarks/dashboard.rb
#
# RUNS=5 sets the number of timed runs, EXPLAIN=1 prints EXPLAIN (ANALYZE, BUFFERS) for queries over 20ms.

abort "Run against a *_benchmark database (set DATABASE_URL)" unless
  ActiveRecord::Base.connection.current_database.end_with?("_benchmark")

ApplicationController.prepend(
  Module.new do
    def current_user = @current_user ||= User.find_by!(uid: "benchmark")
    def refresh_user_installations; end
  end
)

paths = ["/app", "/app?date_range=last_90d", "/app?branch_name=branch-42", "/charts/total_checks"]
runs = Integer(ENV.fetch("RUNS", "5"))
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = "localhost"

profile = lambda do |path|
  queries = []
  callback = lambda do |event|
    next if event.payload[:name].in?(%w[SCHEMA EXPLAIN]) || event.payload[:cached]

    queries << {ms: event.duration, sql: event.payload[:sql], binds: event.payload[:type_casted_binds]}
  end
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { session.get(path) }
  abort "#{path} returned #{session.response.status}" unless session.response.status == 200

  [(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, queries]
end

paths.each do |path|
  profile.call(path)
  timings = Array.new(runs) { profile.call(path) }
  total_ms = timings.map(&:first).sort[runs / 2]
  queries = timings.last.last

  puts "\n== GET #{path}: median #{total_ms.round}ms over #{runs} runs, SQL #{queries.sum { it[:ms] }.round}ms"
  queries.sort_by { -it[:ms] }.first(5).each do |q|
    puts "  #{q[:ms].round(1).to_s.rjust(8)}ms  #{q[:sql].squish.truncate(150)}"
    next unless ENV["EXPLAIN"] && q[:ms] > 20

    binds = (q[:binds].respond_to?(:call) ? q[:binds].call : q[:binds]) || []
    plan = ActiveRecord::Base.connection.exec_query("EXPLAIN (ANALYZE, BUFFERS) #{q[:sql]}", "EXPLAIN", binds)
    plan.rows.each { |(line)| puts "              #{line}" }
  end
end

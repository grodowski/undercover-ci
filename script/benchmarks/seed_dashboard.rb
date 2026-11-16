# frozen_string_literal: true

abort "Run against a *_benchmark database (set DATABASE_URL)" unless
  ActiveRecord::Base.connection.current_database.end_with?("_benchmark")

target_checks = Integer(ENV.fetch("CHECKS", "120000"))
noise_checks = target_checks * 3
noise_installations = 1000
branches = 3000
span_days = 900
chunk_days = 15

conn = ActiveRecord::Base.connection
conn.execute("TRUNCATE coverage_checks, nodes, user_installations, installations, users RESTART IDENTITY CASCADE")
conn.execute("SELECT setseed(0.284)")

user = User.create!(uid: "benchmark", name: "benchmark", email: "benchmark@example.com", token: "benchmark")
target = Installation.create!(
  installation_id: 900_000_065,
  metadata: {account: {login: "bench-org"}, target_type: "Organization"},
  repos: [{full_name: "bench-org/monorepo", visibility: "private"}]
)
user.installations << target

conn.execute(<<~SQL)
  INSERT INTO installations (installation_id, metadata, repos, created_at, updated_at)
  SELECT 910_000_000 + n, '{"target_type": "Organization"}'::jsonb,
         jsonb_build_array(jsonb_build_object('full_name', 'noise-' || n || '/repo', 'visibility', 'private')),
         now(), now()
  FROM generate_series(1, #{noise_installations}) n
SQL
noise_ids = conn.select_values("SELECT id FROM installations WHERE id <> #{target.id} ORDER BY id")

# ~2.4KB check_suite like production: the GitHub payload, with a hard to compress commit message
check_suite_sql = <<~SQL
  jsonb_build_object(
    'id', 100000000000 + r.n,
    'head_branch', 'branch-' || (r.n % #{branches}),
    'head_sha', r.sha,
    'status', 'completed',
    'conclusion', 'success',
    'url', 'https://api.github.com/repos/' || r.full_name || '/check-suites/' || r.n,
    'before', md5(r.n::text || 'before') || substr(md5(r.n::text), 1, 8),
    'after', r.sha,
    'pull_requests', '[]'::jsonb,
    'app', jsonb_build_object('id', 18310, 'slug', 'undercoverci', 'name', 'UndercoverCI'),
    'head_commit', jsonb_build_object(
      'id', r.sha,
      'message', concat(#{(1..56).map { "md5(r.n::text || '#{it}')" }.join(', ')}),
      'author', jsonb_build_object('name', 'Dev', 'email', 'dev@example.com')
    )
  )
SQL

rows_sql = lambda do |installation_sql, full_name_sql, count, from_day|
  <<~SQL
    SELECT #{installation_sql} AS installation_id, #{full_name_sql} AS full_name,
           now() - make_interval(secs => (#{from_day} + random() * #{chunk_days}) * 86400) AS ts
    FROM generate_series(1, #{count}) g
  SQL
end

(0...span_days).step(chunk_days).reverse_each do |from_day|
  target_count = (target_checks * chunk_days / span_days.to_f).round
  noise_count = (noise_checks * chunk_days / span_days.to_f).round
  noise_installation_sql = "(ARRAY[#{noise_ids.join(',')}]::bigint[])[1 + floor(random() * #{noise_ids.size})::int]"

  conn.execute(<<~SQL)
    INSERT INTO coverage_checks (installation_id, head_sha, base_sha, repo, check_suite, state, result,
                                 state_log, event_log, created_at, updated_at)
    SELECT r.installation_id, r.sha, 'master',
           jsonb_build_object('full_name', r.full_name, 'visibility', 'private', 'default_branch', 'master'),
           #{check_suite_sql},
           'complete', CASE WHEN random() < 0.8 THEN 'passed' ELSE 'failed' END,
           jsonb_build_array(jsonb_build_object('to', 'complete', 'ts', r.ts, 'via', 'benchmark')),
           '[]'::jsonb, r.ts, r.ts
    FROM (
      SELECT s.*, row_number() OVER (ORDER BY s.ts) + #{from_day.to_i * 1_000_000} AS n,
             md5(random()::text) || substr(md5(random()::text), 1, 8) AS sha
      FROM (
        #{rows_sql.call(target.id, "'bench-org/monorepo'", target_count, from_day)}
        UNION ALL
        #{rows_sql.call(noise_installation_sql, "'noise/repo'", noise_count, from_day)}
      ) s
    ) r
    ORDER BY r.ts
  SQL
  puts "seeded days #{from_day}-#{from_day + chunk_days} ago"
end

conn.execute("VACUUM ANALYZE coverage_checks")
counts = conn.select_one(<<~SQL)
  SELECT count(*) AS total,
         count(*) FILTER (WHERE installation_id = #{target.id}) AS target,
         count(*) FILTER (WHERE installation_id = #{target.id} AND created_at > now() - interval '90 days') AS target_90d,
         pg_size_pretty(pg_total_relation_size('coverage_checks')) AS size
  FROM coverage_checks
SQL
puts counts.inspect

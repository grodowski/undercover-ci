# frozen_string_literal: true

require "rails_helper"
require "rake"

describe "reports:merge_outcomes" do
  let(:now) { Time.zone.parse("2026-10-17 12:00:00 UTC") }
  let(:installation) do
    Installation.create!(
      installation_id: 123_123, metadata: {"target_type" => "Organization", "account" => {"login" => "acme"}}
    )
  end
  let(:quiet_installation) do
    Installation.create!(
      installation_id: 456, metadata: {"target_type" => "Organization", "account" => {"login" => "quiet"}}
    )
  end

  before(:context) { Rails.application.load_tasks unless Rake::Task.task_defined?("reports:merge_outcomes") }

  before do
    Timecop.freeze(now)
    seed
    stub_request(:post, "https://api.github.com/app/installations/123123/access_tokens")
      .to_return(status: 200, body: {token: "token"}.to_json, headers: {"Content-Type" => "application/json"})
    stub_request(:get, "https://api.github.com/repos/acme/api/git/ref/pull/3/head")
      .to_return(status: 200, body: {object: {sha: "fork"}}.to_json, headers: {"Content-Type" => "application/json"})
  end

  after { Timecop.return }

  def check(installation, sha, check_suite, result: "passed", created_at: now - 2.days)
    CoverageCheck.create!(
      installation:, head_sha: sha, state: :complete, result:, created_at:, check_suite:,
      state_log: [{"to" => "complete", "ts" => (created_at + 1.minute).iso8601}],
      repo: {"full_name" => "#{installation.metadata.dig('account', 'login')}/api", "default_branch" => "main"}
    )
  end

  def pr_check(installation, sha, number, **)
    check(installation, sha, {"head_branch" => "feature", "pull_requests" => number ? [{"number" => number}] : []}, **)
  end

  def merge_check(installation, sha, message)
    merged_at = now - 1.day + 1.hour
    suite = {"head_branch" => "main", "head_commit" => {"message" => message, "timestamp" => merged_at.iso8601}}
    check(installation, sha, suite, created_at: now - 1.day)
  end

  def seed
    warned = pr_check(installation, "a1", 1, result: "failed")
    warned.nodes.create!(
      path: "app/models/charge.rb", node_type: "instance method", node_name: "refund",
      start_line: 1, end_line: 2, coverage: 0.5, flagged: true
    )
    pr_check(installation, "b1", 2, result: "failed", created_at: now - 3.days)
    pr_check(installation, "b2", 2)
    pr_check(installation, "fork", nil, result: "failed")
    merge_check(installation, "m1", "Merge pull request #1 from acme/refund")
    merge_check(installation, "m2", "Add charges (#2)")
    merge_check(installation, "m3", "Fork fix (#3)")
    merge_check(installation, "m4", "Bump version")
    pr_check(quiet_installation, "q1", 5)
    merge_check(quiet_installation, "q2", "Quiet (#5)")
  end

  def run_task(*)
    Rake::Task["reports:merge_outcomes"].reenable
    Rake::Task["reports:merge_outcomes"].invoke(*)
  end

  def snapshot
    [CoverageCheck, Node, Installation, Subscription, User].to_h do |model|
      [model.name, [model.count, model.maximum(:updated_at)]]
    end
  end

  it "prints an email draft for every installation with merged pull requests, without writing anything" do
    before = snapshot

    expect { run_task }.to output(<<~TEXT).to_stdout
      === acme (installation 123123) · 7 days ===

      Subject: Your UndercoverCI stats for the last week

      Hey acme,

      here are your UndercoverCI stats for the last week:

      - 1 went from red to green: UndercoverCI flagged untested code and the tests were added before merging
      - 3 pull requests merged
      - 1 fully tested when they merged
      - 2 merged with untested code:
        - https://github.com/acme/api/pull/1 (refund)
        - https://github.com/acme/api/pull/3

      Do you find this useful? I'm researching more advanced coverage reporting views for UndercoverCI and I'm curious to learn what else you'd like to see.

      Jan
      === quiet (installation 456) · 7 days ===

      Subject: Your UndercoverCI stats for the last week

      Hey quiet,

      here are your UndercoverCI stats for the last week:

      - 1 pull request merged
      - 1 fully tested when they merged

      Do you find this useful? I'm researching more advanced coverage reporting views for UndercoverCI and I'm curious to learn what else you'd like to see.

      Jan
    TEXT

    expect(snapshot).to eq(before)
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(WebMock).to have_requested(:get, "https://api.github.com/repos/acme/api/git/ref/pull/3/head").once
    expect(WebMock).not_to have_requested(:any, /api\.github\.com\/repos\/.*check-runs/)
  end

  it "does not enqueue jobs or deliver mail" do
    deliveries = ActionMailer::Base.deliveries.size

    expect { run_task }.to output.to_stdout.and(have_enqueued_job.exactly(0))
    expect(ActionMailer::Base.deliveries.size).to eq(deliveries)
  end

  it "blocks database writes while reporting" do
    allow(Logic::MergeOutcomes).to receive(:call).and_wrap_original do |original, *args, **kwargs|
      CoverageCheck.first.touch
      original.call(*args, **kwargs)
    end

    expect { run_task }.to raise_error(ActiveRecord::ReadOnlyError)
  end

  it "reports a single installation by its GitHub id" do
    expect { run_task("30", "456") }.to output(/\A=== quiet \(installation 456\) · 30 days ===\n/).to_stdout
  end

  it "rejects DAYS other than 7, 14 or 30" do
    expect { run_task("10") }.to raise_error(SystemExit).and output("DAYS must be one of 7, 14, 30\n").to_stderr
    expect { run_task("week") }.to raise_error(SystemExit).and output(/DAYS must be one of/).to_stderr
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Logic::MergeOutcomes do
  let(:now) { Time.zone.parse("2026-10-17 12:00:00 UTC") }
  let(:installation) do
    Installation.create!(
      installation_id: 123_123,
      metadata: {
        "target_type" => "Organization",
        "account" => {"login" => "acme"}
      }
    )
  end

  def merge_check(message, merged_at, repo: "acme/api", branch: "main")
    sha = SecureRandom.hex(20)
    CoverageCheck.create!(
      installation:, head_sha: sha, state: :complete, result: "passed", created_at: merged_at + 1.minute,
      repo: {"full_name" => repo, "default_branch" => "main"},
      check_suite: {
        "head_branch" => branch,
        "head_sha" => sha,
        "pull_requests" => [],
        "head_commit" => {"id" => sha, "message" => message, "timestamp" => merged_at.utc.iso8601}
      }
    )
  end

  def pr_check(number, created_at:, completed_at: created_at + 5.minutes, repo: "acme/api", **attrs)
    attrs = {state: :complete, result: "passed", head_sha: SecureRandom.hex(20)}.merge(attrs)
    finished = attrs[:state].in?(%i[complete canceled]) && completed_at
    state_log = finished ? [{"to" => attrs[:state].to_s, "ts" => completed_at.utc.iso8601}] : []
    CoverageCheck.create!(
      installation:, created_at:, state_log:, **attrs,
      repo: {"full_name" => repo, "default_branch" => "main"},
      check_suite: {"head_branch" => "feature", "pull_requests" => number ? [{"number" => number}] : []}
    )
  end

  def flag_nodes(check, count)
    count.times do |i|
      check.nodes.create!(
        path: "app/m#{i}.rb", node_type: "instance method", node_name: "m#{i}",
        start_line: 1, end_line: 2, coverage: 0.5, flagged: true
      )
    end
  end

  def stub_token(status: 200)
    stub_request(:post, "https://api.github.com/app/installations/123123/access_tokens")
      .to_return(status:, body: {token: "token"}.to_json, headers: {"Content-Type" => "application/json"})
  end

  def stub_ref(number, status: 200)
    stub_request(:get, "https://api.github.com/repos/acme/api/git/ref/pull/#{number}/head")
      .to_return(status:, body: {object: {sha: "f0f0"}}.to_json, headers: {"Content-Type" => "application/json"})
  end

  def result(days: 7) = described_class.call(installation, days:, now:)

  def outcomes(window) = window.pull_requests.to_h { [it.number, it.outcome] }

  describe ".pr_number" do
    it "parses merge commits and squash merges from the first line only" do
      expect(described_class.pr_number("Merge pull request #12 from acme/feature\n\nAdd x")).to eq(12)
      expect(described_class.pr_number("Add x (#34)")).to eq(34)
      expect(described_class.pr_number("Add x (#34)  \n\nbody")).to eq(34)
      expect(described_class.pr_number("Bump version\n\n* Add x (#34)")).to be_nil
      expect(described_class.pr_number("Merge branch 'main' into feature")).to be_nil
      expect(described_class.pr_number("Fix #12 in parser")).to be_nil
      expect(described_class.pr_number(nil)).to be_nil
    end
  end

  it "rejects DAYS other than 7, 14 or 30" do
    expect do
      described_class.new(installation, days: 10)
    end.to raise_error(ArgumentError, "DAYS must be one of 7, 14, 30")
    expect(described_class.new(installation, days: 30).days).to eq(30)
  end

  it "computes the outcome of each pull request at merge time" do
    merged_at = now - 1.day
    { # number => [state, result, completed_at]
      1 => [:complete, "passed", merged_at - 1.hour],
      2 => [:complete, "failed", merged_at - 1.hour],
      3 => [:in_progress, nil, nil],
      4 => [:complete, "passed", merged_at + 1.hour],
      5 => [:canceled, nil, merged_at - 1.hour],
      6 => [:awaiting_coverage, nil, nil],
      7 => [:canceled, nil, merged_at + 1.hour]
    }.each do |number, (state, check_result, completed_at)|
      pr_check(number, created_at: merged_at - 2.hours, state:, result: check_result, completed_at:)
      merge_check("Add feature (##{number})", merged_at)
    end
    pr_check(1, created_at: merged_at + 1.minute, result: "failed")

    expect(outcomes(result.current)).to eq(
      1 => :passed, 2 => :merged_with_warnings, 3 => :merged_before_check,
      4 => :merged_before_check, 5 => :no_coverage, 6 => :merged_before_check, 7 => :merged_before_check
    )
  end

  it "treats flagged nodes as warnings when result is missing" do
    check = pr_check(1, created_at: now - 2.days, result: nil)
    flag_nodes(check, 1)
    merge_check("Merge pull request #1 from acme/x", now - 1.day)

    expect(outcomes(result.current)).to eq(1 => :merged_with_warnings)
  end

  it "dedupes merges by repo and number, counts pushes without a PR number and ignores other branches" do
    pr_check(1, created_at: now - 3.days)
    merge_check("Add x (#1)", now - 2.days)
    merge_check("Add x (#1)", now - 2.days + 1.minute)
    merge_check("Bump version", now - 2.days)
    merge_check("Bump version", now - 1.day)
    merge_check("Hotfix", now - 1.day, repo: "acme/web")
    merge_check("WIP (#9)", now - 1.day, branch: "feature")
    merge_check("Old (#8)", now - 20.days)

    current = result.current
    expect(current.pull_requests.map { [it.repo, it.number, it.merged_at] }).to eq([["acme/api", 1, now - 2.days]])
    expect(current.pushes_without_pr).to eq("acme/api" => 2, "acme/web" => 1)
  end

  context "when no check knows the pull request number" do
    before { stub_token }

    it "finds the check by the head sha of refs/pull/N/head" do
      pr_check(nil, created_at: now - 2.days, result: "failed", head_sha: "f0f0")
      merge_check("Add x (#7)", now - 1.day)
      stub_ref(7)

      expect(outcomes(result.current)).to eq(7 => :merged_with_warnings)
      expect(WebMock).to have_requested(:get, "https://api.github.com/repos/acme/api/git/ref/pull/7/head").once
    end

    it "ignores checks with the same head sha in another repository" do
      pr_check(nil, created_at: now - 2.days, head_sha: "f0f0", repo: "acme/api-fork")
      merge_check("Add x (#7)", now - 1.day)
      stub_ref(7)

      expect(outcomes(result.current)).to eq(7 => :no_check)
    end

    it "reports no_check when no check exists for the head sha" do
      merge_check("Add x (#7)", now - 1.day)
      stub_ref(7)

      expect(outcomes(result.current)).to eq(7 => :no_check)
    end

    it "drops numbers that are not pull requests" do
      merge_check("Fix the thing (#7)", now - 1.day)
      stub_ref(7, status: 404)

      expect(result.current.pull_requests).to be_empty
    end

    it "marks pull requests unresolved when the GitHub API fails" do
      merge_check("Add x (#7)", now - 1.day)
      stub_ref(7, status: 500)

      expect(outcomes(result.current)).to eq(7 => :unresolved)
    end

    it "marks pull requests unresolved when the installation token cannot be created" do
      stub_token(status: 404)
      merge_check("Add x (#7)", now - 1.day)
      merge_check("Add y (#8)", now - 1.day)

      expect(outcomes(result.current)).to eq(7 => :unresolved, 8 => :unresolved)
      expect(WebMock).to have_requested(:post, "https://api.github.com/app/installations/123123/access_tokens").once
    end
  end

  it "marks passed pull requests with an earlier check with warnings as caught before merge" do
    pr_check(1, created_at: now - 3.days, result: "failed")
    pr_check(1, created_at: now - 2.days)
    pr_check(2, created_at: now - 2.days)
    pr_check(3, created_at: now - 3.days)
    pr_check(3, created_at: now - 2.days, result: "failed")
    [1, 2, 3].each { merge_check("Add (##{it})", now - 1.day) }

    expect(result.current.pull_requests.to_h { [it.number, it.caught] }).to eq(1 => true, 2 => false, 3 => false)
    expect(result.current.caught_count).to eq(1)
  end

  it "counts as caught only a warning check that finished before the passing one" do
    pr_check(1, created_at: now - 3.days, completed_at: now - 1.day + 2.hours, result: "failed")
    pr_check(1, created_at: now - 2.days)
    merge_check("Add (#1)", now - 1.day + 3.hours)

    expect(result.current.pull_requests.map(&:caught)).to eq([false])
  end

  it "reads the whole history of a merged pull request, not only the report window" do
    pr_check(1, created_at: now - 40.days, result: "failed")
    pr_check(1, created_at: now - 2.days)
    merge_check("Add (#1)", now - 1.day)

    expect(result(days: 7).current.pull_requests.map(&:caught)).to eq([true])
  end

  it "computes the previous window of the same length" do
    pr_check(1, created_at: now - 12.days, result: "failed")
    pr_check(2, created_at: now - 12.days, result: "failed")
    pr_check(3, created_at: now - 2.days, result: "failed")
    merge_check("Add (#1)", now - 10.days)
    merge_check("Add (#2)", now - 9.days)
    merge_check("Add (#3)", now - 1.day)
    merge_check("Bump", now - 9.days)

    res = result
    expect(res.previous.from).to eq(now - 14.days)
    expect(res.previous.to).to eq(now - 7.days)
    expect(outcomes(res.previous)).to eq(1 => :merged_with_warnings, 2 => :merged_with_warnings)
    expect(res.previous.pushes_without_pr).to eq("acme/api" => 1)
    expect(outcomes(res.current)).to eq(3 => :merged_with_warnings)
    expect(outcomes(result(days: 14).current).keys).to contain_exactly(1, 2, 3)
  end

  it "loads up to 3 flagged nodes for pull requests merged with warnings in the current window" do
    flag_nodes(pr_check(1, created_at: now - 2.days, result: "failed"), 4)
    flag_nodes(pr_check(2, created_at: now - 9.days, result: "failed"), 1)
    merge_check("Add (#1)", now - 1.day)
    merge_check("Add (#2)", now - 8.days)

    res = result
    expect(res.current.with_warnings.first.flagged_nodes).to eq(
      (0..2).map { {type: "instance method", name: "m#{it}", path: "app/m#{it}.rb"} }
    )
    expect(res.previous.with_warnings.first.flagged_nodes).to eq([])
  end

  it "names the account by its GitHub login" do
    expect(result.account).to eq("acme")
    expect(result.with(installation: Installation.new(installation_id: 9)).account).to eq("9")
  end

  it "lists installations with merges in the window" do
    other = Installation.create!(installation_id: 456)
    merge_check("Add (#1)", now - 1.day)
    CoverageCheck.create!(installation: other, repo: {}, check_suite: {}, created_at: now - 1.day)

    expect(described_class.installations_with_merges(7, now:)).to eq([installation])
  end
end

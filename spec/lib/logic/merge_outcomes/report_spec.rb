# frozen_string_literal: true

require "rails_helper"

describe Logic::MergeOutcomes::Report do
  let(:now) { Time.zone.parse("2026-10-17 12:00:00 UTC") }
  let(:installation) { Installation.new(installation_id: 123_123, metadata: {"account" => {"login" => "acme"}}) }

  def pr(number, outcome, caught: false, names: [])
    Logic::MergeOutcomes::PullRequest.new(
      repo: "acme/api", number:, merged_at: now - 1.day, check_id: number, outcome:, caught:,
      flagged_nodes: names.map { {type: "instance method", name: it, path: "app/#{it}.rb"} }
    )
  end

  def report(pull_requests, days: 30)
    window = Logic::MergeOutcomes::Window.new(
      from: now - days.days, to: now, pull_requests:, pushes_without_pr: {"acme/api" => 2}
    )
    described_class.new(Logic::MergeOutcomes::Result.new(installation:, days:, current: window, previous: window))
  end

  it "prints an operator header and the email draft" do
    pull_requests = [
      pr(1, :passed),
      pr(2, :passed, caught: true),
      pr(3, :passed, caught: true),
      pr(4, :merged_with_warnings, names: %w[charge block charge refund void sync]),
      pr(5, :merged_before_check),
      pr(6, :no_coverage),
      pr(7, :no_check),
      pr(8, :unresolved)
    ]

    expect(report(pull_requests).to_s).to eq(<<~TEXT)
      === acme (installation 123123) · 30 days · 1 pull request not resolved on GitHub ===

      Subject: Your UndercoverCI stats for the last 30 days

      Hey acme,

      here are your UndercoverCI stats for the last 30 days:

      - 2 went from red to green: UndercoverCI flagged untested code and the tests were added before merging
      - 8 pull requests merged
      - 3 fully tested when they merged
      - 1 merged with untested code:
        - https://github.com/acme/api/pull/4 (charge, refund, void)
      - 1 merged before the coverage check finished
      - 1 merged without a coverage report
      - 1 merged without a coverage check

      Do you find this useful? I'm researching more advanced coverage reporting views for UndercoverCI and I'm curious to learn what else you'd like to see.

      Jan
    TEXT
  end

  it "leaves out zero counts and the unresolved note" do
    text = report([pr(1, :passed), pr(2, :passed)], days: 7).to_s

    expect(text).to start_with("=== acme (installation 123123) · 7 days ===\n")
    expect(text).to include("for the last week:\n\n- 2 pull requests merged\n- 2 fully tested when they merged\n\n")
    expect(text).not_to include("red to green", "untested code", "before the coverage check", "without a coverage")
  end

  it "lists up to 3 pull requests with untested code and skips unnamed blocks" do
    text = report((1..5).map { pr(it, :merged_with_warnings, names: %w[block]) }).to_s

    expect(text).to include(
      "- 5 merged with untested code:\n  - https://github.com/acme/api/pull/1\n  " \
      "- https://github.com/acme/api/pull/2\n  - https://github.com/acme/api/pull/3\n  - and 2 more\n"
    )
  end

  it "is notable only with merged pull requests" do
    expect(report([pr(1, :passed)])).to be_notable
    expect(report([])).not_to be_notable
  end
end

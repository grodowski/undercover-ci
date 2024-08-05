# frozen_string_literal: true

require "check_runs"
require "rails_helper"

describe CheckRuns::Canceled do
  let(:coverage_check) do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", users: [user])
    CoverageCheck.create!(
      installation:,
      head_sha: "b8f95245", # commit sha from fake_repo feature branch
      repo: {"full_name" => "author/repo", "default_branch" => "master"},
      state: :in_progress
    )
  end

  it "concludes the CheckRun that timed out" do
    run = DataObjects::CheckRunInfo.new(
      "grodowski/undercover-ci",
      "abc123",
      "installation-1",
      nil,
      "2020-02-02T16:13:22Z",
      nil,
      :complete,
      coverage_check.id,
      "2020-02-02T16:20:47Z",
      []
    )
    check_run_timed_out = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_timed_out).to receive(:installation_api_client) { dummy_github }

    check_run_timed_out.post

    expect(dummy_github)
      .to have_received(:post) do |path, payload|
        expect(path).to eq("/repos/grodowski/undercover-ci/check-runs")
        expect(payload[:external_id]).to eq(coverage_check.id)
        expect(payload[:conclusion]).to eq("cancelled")
        expect(payload[:status]).to eq("completed")
        expect(payload[:completed_at]).to eq("2020-02-02T16:20:47Z")
        expect(payload[:details_url]).to eq("https://undercover-ci.com/checks/#{coverage_check.id}")
        expect(payload[:output]).to match(
          title: "Timed out waiting for coverage data",
          summary: a_string_including("This check run was unsuccessful for one of the following reasons")
        )
      end
  end

  it "concludes the CheckRun that was canceled with an inactive subscription" do
    coverage_check.installation.subscription.update!(
      state: :unsubscribed, end_date: 2.days.ago
    )
    coverage_check.reload

    run = DataObjects::CheckRunInfo.new(
      "grodowski/undercover-ci",
      "abc123",
      "installation-1",
      nil,
      "2020-02-02T16:13:22Z",
      nil,
      :complete,
      coverage_check.id,
      "2020-02-02T16:20:47Z",
      []
    )
    check_run_timed_out = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_timed_out).to receive(:installation_api_client) { dummy_github }

    check_run_timed_out.post

    expect(dummy_github)
      .to have_received(:post) do |path, payload|
        expect(path).to eq("/repos/grodowski/undercover-ci/check-runs")
        expect(payload[:external_id]).to eq(coverage_check.id)
        expect(payload[:conclusion]).to eq("cancelled")
        expect(payload[:status]).to eq("completed")
        expect(payload[:completed_at]).to eq("2020-02-02T16:20:47Z")
        expect(payload[:details_url]).to eq("https://undercover-ci.com/checks/#{coverage_check.id}")
        expect(payload[:output]).to match(
          title: "License expired",
          summary: a_string_including("🔐 Your UndercoverCI license has expired")
        )
      end
  end

  it "skips the CheckRun that was canceled by user" do
    Logic::UpdateCoverageCheckState.new(coverage_check).cancel("Cancelled by user")

    run = DataObjects::CheckRunInfo.new(
      "grodowski/undercover-ci",
      "abc123",
      "installation-1",
      nil,
      "2020-02-02T16:13:22Z",
      nil,
      :complete,
      coverage_check.id,
      "2020-02-02T16:20:47Z",
      []
    )
    check_run_timed_out = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_timed_out).to receive(:installation_api_client) { dummy_github }

    check_run_timed_out.post

    expect(dummy_github)
      .to have_received(:post) do |path, payload|
        expect(path).to eq("/repos/grodowski/undercover-ci/check-runs")
        expect(payload[:external_id]).to eq(coverage_check.id)
        expect(payload[:conclusion]).to eq("skipped")
        expect(payload[:status]).to eq("completed")
        expect(payload[:completed_at]).to eq("2020-02-02T16:20:47Z")
        expect(payload[:details_url]).to eq("https://undercover-ci.com/checks/#{coverage_check.id}")
        expect(payload[:output]).to match(
          title: "Check skipped",
          summary: a_string_including("⏩ This check was manually skipped by a user")
        )
      end
  end
end

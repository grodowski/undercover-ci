# frozen_string_literal: true

require "rails_helper"
require "check_runs"

describe CheckRuns::TimedOut do
  it "concludes the CheckRun with timed_out" do
    run = DataObjects::CheckRunInfo.new(
      "grodowski/undercover-ci",
      "abc123",
      "installation-1",
      nil,
      "2020-02-02T16:13:22Z",
      nil,
      :complete,
      1337,
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
        expect(payload[:external_id]).to eq(1337)
        expect(payload[:conclusion]).to eq("timed_out")
        expect(payload[:status]).to eq("completed")
        expect(payload[:completed_at]).to eq("2020-02-02T16:20:47Z")
        expect(payload[:details_url]).to eq("https://undercover-ci.com/checks/1337")
        expect(payload[:output]).to match(
          title: "Timed Out",
          summary: "UndercoverCI did not receive coverage data for this check"
        )
      end
  end
end

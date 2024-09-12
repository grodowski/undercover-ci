# frozen_string_literal: true

require "rails_helper"

describe Logic::UpdateCoverageCheckState do
  let(:coverage_check) do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", users: [user])
    CoverageCheck.create!(installation:, repo: {id: 1, full_name: "user/repository"}, head_sha: "b4c0n")
  end
  let(:svc) do
    described_class.new(coverage_check)
  end

  it "updates state to awaiting_coverage" do
    expect { svc.await_coverage }.to change { coverage_check.reload.state }.from(:created).to(:awaiting_coverage)
  end

  it "updates state from awaiting_coverage to canceled" do
    coverage_check.update!(state: :awaiting_coverage)
    expect { svc.cancel }.to change { coverage_check.reload.state }.from(:awaiting_coverage).to(:canceled)
  end

  it "updates state from in_progress to canceled" do
    coverage_check.update!(state: :in_progress)
    expect { svc.cancel }.to change { coverage_check.reload.state }.from(:in_progress).to(:canceled)
  end

  it "updates state to queued" do
    coverage_check.update!(state: :awaiting_coverage)
    expect { svc.enqueue }.to change { coverage_check.reload.state }.from(:awaiting_coverage).to(:queued)
  end

  it "updates state to in_progress" do
    coverage_check.update!(state: :queued)
    expect { svc.start }.to change { coverage_check.reload.state }.from(:queued).to(:in_progress)
  end

  it "updates state to complete" do
    coverage_check.update!(state: :in_progress)
    expect { svc.complete }.to change { coverage_check.reload.state }.from(:in_progress).to(:complete)
  end

  it "raises a StateTransisionError if initial state is invalid" do
    expect { svc.complete }.to raise_error(Logic::StateTransisionError)
  end

  it "restarts" do
    coverage_check.update!(state: :in_progress)
    Timecop.freeze do
      expect { svc.restart }.to change { coverage_check.reload.state }.from(:in_progress).to(:awaiting_coverage)
      expect_state_log("in_progress", "awaiting_coverage", Time.now, "restart")
    end
  end

  def expect_state_log(from, to, time, via)
    expect(coverage_check.state_log.map(&:symbolize_keys)).to include(
      from:,
      to:,
      ts: time.utc.iso8601,
      via:
    )
  end
end

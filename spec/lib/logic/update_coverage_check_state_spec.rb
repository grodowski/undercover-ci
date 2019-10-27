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
    installation = Installation.create!(installation_id: "123123", user: user)
    CoverageCheck.create!(installation: installation, repo: {id: 1, full_name: "user/repository"}, head_sha: "b4c0n")
  end
  let(:svc) do
    described_class.new(coverage_check)
  end

  it "updates state to awaiting_coverage" do
    expect { svc.await_coverage }.to change { coverage_check.reload.state }.from(:created).to(:awaiting_coverage)
  end

  it "updates state to in_progress" do
    coverage_check.update!(state: :awaiting_coverage)
    expect { svc.start }.to change { coverage_check.reload.state }.from(:awaiting_coverage).to(:in_progress)
  end

  it "updates state to complete" do
    coverage_check.update!(state: :in_progress)
    expect { svc.complete }.to change { coverage_check.reload.state }.from(:in_progress).to(:complete)
  end

  it "raises a StateTransisionError if initial state is invalid" do
    expect { svc.complete }.to raise_error(Logic::StateTransisionError)
  end

  it "restarts" do
    coverage_check.update!(state: :awaiting_coverage)
    Timecop.freeze do
      expect do
        svc.start
        svc.restart
      end.to change { coverage_check.reload.state }.from(:awaiting_coverage).to(:in_progress)
      expect_state_log("awaiting_coverage", "in_progress", Time.now, nil)
      expect_state_log("in_progress", "in_progress", Time.now, "restart")
    end
  end

  def expect_state_log(from, to, time, via)
    expect(coverage_check.state_log.map(&:symbolize_keys)).to include(
      from: from,
      to: to,
      ts: time.utc.iso8601,
      via: via
    )
  end
end

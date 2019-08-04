# frozen_string_literal: true

require "rails_helper"

describe Logic::UpdateCoverageCheckState do
  let(:coverage_check) do
    CoverageCheck.create!(repo: {id: 1, full_name: "user/repository"}, head_sha: "b4c0n")
  end
  let(:svc) do
    described_class.new(coverage_check)
  end

  it "updates state to queued" do
    expect { svc.queue }.to change { coverage_check.reload.state }.from(:created).to(:queued)
  end

  it "updates state to in_progress" do
    expect { svc.start }.to change { coverage_check.reload.state }.from(:created).to(:in_progress)
  end

  it "updates state to complete" do
    expect { svc.complete }.to change { coverage_check.reload.state }.from(:created).to(:complete)
  end

  it "restarts" do
    Timecop.freeze do
      expect do
        svc.start
        svc.restart
      end.to change { coverage_check.reload.state }.from(:created).to(:in_progress)
      expect_state_log("created", "in_progress", Time.now, nil)
      expect_state_log("in_progress", "in_progress", Time.now, "restart")
    end
  end

  def expect_state_log(from, to, time, via)
    expect(coverage_check.state_log.map(&:symbolize_keys)).to include(
      from: from,
      to: to,
      ts: time.iso8601,
      via: via
    )
  end
end

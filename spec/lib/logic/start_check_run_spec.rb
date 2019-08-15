# frozen_string_literal: true

require "rails_helper"

describe Logic::StartCheckRun do
  let(:check_run_info) do
    DataObjects::CheckRunInfo.new("author/repo", "b4c0n1", "master", "123123", nil, nil)
  end

  it "creates CoverageCheck in awaiting_coverage and dispatches a CreateCheckRunJob" do
    expect(CreateCheckRunJob).to receive(:perform_later).once

    described_class.call(check_run_info)

    coverage_check = CoverageCheck.last
    expect(coverage_check.state).to eq(:awaiting_coverage)
    expect(coverage_check).to be_persisted
  end

  it "returns silently and logs if CoverageCheck's state is not 'created'" do
    coverage_check = CoverageCheck.create!(
      head_sha: "b4c0n1", installation_id: "123123", state: :awaiting_coverage
    )

    expect(CreateCheckRunJob).not_to receive(:perform_later)
    expect { described_class.call(check_run_info) }.not_to change(CoverageCheck, :count)
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Logic::StartCheckRun do
  let(:check_run_info) do
    DataObjects::CheckRunInfo.new("author/repo", "b4c0n1", "c0mp4r3", "123123", nil, nil)
  end
  let(:user) do
    User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
  end
  let!(:installation) { Installation.create!(installation_id: "123123", user: user) }

  xit "fails if installation does not exist" do
    # TODO: implement sad path
  end

  it "creates CoverageCheck in awaiting_coverage and dispatches a CreateCheckRunJob" do
    expect(CreateCheckRunJob).to receive(:perform_later).once

    described_class.call(check_run_info)

    coverage_check = CoverageCheck.last
    expect(coverage_check.state).to eq(:awaiting_coverage)
    expect(coverage_check.head_sha).to eq("b4c0n1")
    expect(coverage_check.base_sha).to eq("c0mp4r3")
    expect(coverage_check).to be_persisted
  end

  it "returns silently and logs if CoverageCheck's state is not 'created'" do
    CoverageCheck.create!(
      installation: installation, head_sha: "b4c0n1", base_sha: "c0mp4r3", state: :awaiting_coverage
    )

    expect(CreateCheckRunJob).not_to receive(:perform_later)
    expect { described_class.call(check_run_info) }.not_to change(CoverageCheck, :count)
  end

  context "with a check_suite payload from GitHub" do
    let(:check_run_info) do
      DataObjects::CheckRunInfo.new("author/repo", "b4c0n1", "c0mp4r3", "123123", nil, payload)
    end
    let(:payload) do
      OpenStruct.new(
        "check_suite" => {"id" => "1234"},
        "repository" => {"full_name" => "grodowski/undercover-ci"}
      )
    end

    it "stores the repository and check_suite keys" do
      expect(CreateCheckRunJob).to receive(:perform_later).once
      described_class.call(check_run_info)

      coverage_check = CoverageCheck.last
      expect(coverage_check.check_suite).to eq("id" => "1234")
      expect(coverage_check.repo).to eq("full_name" => "grodowski/undercover-ci")
    end
  end
end

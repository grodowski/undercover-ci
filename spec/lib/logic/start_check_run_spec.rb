# frozen_string_literal: true

require "rails_helper"

describe Logic::StartCheckRun do
  let(:check_run_info) do
    DataObjects::CheckRunInfo.new("author/repo", "b4c0n1", "c0mp4r3", installation_id, nil, payload)
  end
  let(:installation_id) { "123123" }
  let(:payload) { OpenStruct.new("repository" => {"visibility" => "private"}) }
  let(:user) do
    User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
  end
  let(:installation) { Installation.create!(installation_id: installation_id, users: [user]) }

  it "fails if installation does not exist" do
    expect(CreateCheckRunJob).not_to receive(:perform_later)

    expect { described_class.call(check_run_info) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "creates CoverageCheck in awaiting_coverage and dispatches a CreateCheckRunJob" do
    installation.itself
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
      installation:, head_sha: "b4c0n1", base_sha: "c0mp4r3", state: :awaiting_coverage
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
      installation.itself
      expect(CreateCheckRunJob).to receive(:perform_later).once

      Timecop.freeze do
        described_class.call(check_run_info)

        coverage_check = CoverageCheck.last
        expect(ExpireCheckJob).to have_been_enqueued.at(120.minutes.from_now).with(coverage_check.id)
        expect(coverage_check.check_suite).to eq("id" => "1234")
        expect(coverage_check.repo).to eq("full_name" => "grodowski/undercover-ci")
      end
    end

    it "respects custom expire_check_job_wait_minutes" do
      installation.update!(expire_check_job_wait_minutes: 7)
      expect(CreateCheckRunJob).to receive(:perform_later).once

      Timecop.freeze do
        described_class.call(check_run_info)

        coverage_check = CoverageCheck.last
        expect(ExpireCheckJob).to have_been_enqueued.at(7.minutes.from_now).with(coverage_check.id)
      end
    end
  end

  context "with an active subscription" do
    before do
      installation.subscriptions.create(
        state: :subscribed, gumroad_id: "subxxx", license_key: "1337"
      )
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
  end

  context "with an inactive subscription" do
    before do
      installation.subscriptions.create(
        state: :unsubscribed, gumroad_id: "subxxx", license_key: "1337",
        end_date: 1.day.ago
      )
    end

    it "enqueues an immediate transition to canceled" do
      expect(CreateCheckRunJob).to receive(:perform_later)

      Timecop.freeze do
        described_class.call(check_run_info)

        coverage_check = CoverageCheck.last
        expect(coverage_check.state).to eq(:awaiting_coverage)
        expect(coverage_check.head_sha).to eq("b4c0n1")
        expect(coverage_check.base_sha).to eq("c0mp4r3")
        expect(coverage_check).to be_persisted

        expect(ExpireCheckJob).to have_been_enqueued.at(5.seconds.from_now).with(coverage_check.id)
      end
    end

    context "and a public repo" do
      let(:payload) { OpenStruct.new("repository" => {"visibility" => "public"}) }

      it "enqueues with default timeout" do
        expect(CreateCheckRunJob).to receive(:perform_later)

        Timecop.freeze do
          described_class.call(check_run_info)

          coverage_check = CoverageCheck.last
          expect(coverage_check.state).to eq(:awaiting_coverage)
          expect(coverage_check.head_sha).to eq("b4c0n1")
          expect(coverage_check.base_sha).to eq("c0mp4r3")
          expect(coverage_check).to be_persisted

          expect(ExpireCheckJob).to have_been_enqueued.at(120.minutes.from_now).with(coverage_check.id)
        end
      end
    end
  end

  context "with branch filtering" do
    let(:payload) do
      OpenStruct.new(
        "check_suite" => {"id" => "1234", "head_branch" => branch_name},
        "repository" => {"full_name" => "grodowski/undercover-ci"}
      )
    end

    context "when per-repo filter is set" do
      let(:installation_id) { "999999" }

      before do
        installation.update!(
          settings: {
            repo_branch_filters: {
              "author/repo" => "^(main|develop)$"
            }
          }
        )
      end

      context "and branch matches per-repo filter" do
        let(:branch_name) { "develop" }

        it "creates coverage check using per-repo filter" do
          installation.itself
          expect(CreateCheckRunJob).to receive(:perform_later).once

          described_class.call(check_run_info)

          coverage_check = CoverageCheck.last
          expect(coverage_check.state).to eq(:awaiting_coverage)
          expect(coverage_check).to be_persisted
        end
      end

      context "and branch does not match per-repo filter" do
        let(:branch_name) { "feature/test" }

        it "skips creating coverage check" do
          installation.itself
          expect(CreateCheckRunJob).not_to receive(:perform_later)

          described_class.call(check_run_info)

          expect(CoverageCheck.count).to eq(0)
        end
      end
    end

    context "when no branch filter is set" do
      let(:branch_name) { "feature/test" }

      it "creates coverage check for any branch" do
        installation.itself
        expect(CreateCheckRunJob).to receive(:perform_later).once

        described_class.call(check_run_info)

        coverage_check = CoverageCheck.last
        expect(coverage_check.state).to eq(:awaiting_coverage)
        expect(coverage_check).to be_persisted
      end
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Logic::ResolveCoverageCheck do
  let(:user) { User.create!(uid: "1337", email: "foo@bar.com", token: "sekritkey", name: "Foo Bar") }
  let!(:installation) do
    Installation.create!(
      installation_id: "123123",
      users: [user],
      repos: [{"full_name" => "author/repo"}]
    )
  end

  before do
    allow(Logic::VerifyPullRequestHead).to receive(:call).and_return(true)
    allow_any_instance_of(Logic::StartCheckRunFromUpload)
      .to receive(:fetch_repository).and_return({"full_name" => "author/repo", "default_branch" => "main"})
    allow(CoverageCheck.connection).to receive(:execute).and_call_original
  end

  it "takes an advisory lock on the repo and sha before creating a check" do
    described_class.call("author/repo", "b4c0n", 42)

    expect(CoverageCheck.connection).to have_received(:execute)
      .with("SELECT pg_advisory_xact_lock(hashtext('author/repo@b4c0n'))")
  end

  it "returns the check created by the first upload to a second one" do
    first = described_class.call("author/repo", "b4c0n", 42)
    second = described_class.call("author/repo", "b4c0n", 42)

    expect(second).to eq(first)
    expect(CoverageCheck.count).to eq(1)
  end

  context "with a check from a check_suite that listed no pull request" do
    let!(:webhook_check) do
      CoverageCheck.create!(
        installation:, head_sha: "b4c0n", base_sha: "main",
        repo: {"id" => 1, "full_name" => "author/repo"}, check_suite: {"pull_requests" => []}
      )
    end

    it "saves the uploaded pull request number once GitHub confirms the head" do
      expect(described_class.call("author/repo", "b4c0n", 42)).to eq(webhook_check)

      expect(Logic::VerifyPullRequestHead).to have_received(:call)
        .with(installation.installation_id, "author/repo", "b4c0n", 42)
      expect(webhook_check.reload.pull_request_number).to eq(42)
    end

    it "ignores a pull request number GitHub doesn't confirm" do
      allow(Logic::VerifyPullRequestHead).to receive(:call).and_return(false)

      described_class.call("author/repo", "b4c0n", 42)

      expect(webhook_check.reload.pull_request_number).to be_nil
    end

    it "keeps the pull request a check_suite already listed" do
      webhook_check.update!(
        check_suite: {"pull_requests" => [{"number" => 7, "base" => {"ref" => "main", "repo" => {"id" => 1}}}]}
      )

      described_class.call("author/repo", "b4c0n", 42)

      expect(Logic::VerifyPullRequestHead).not_to have_received(:call)
      expect(webhook_check.reload.pull_request_number).to be_nil
    end
  end

  it "neither locks nor creates a check without a pull request number" do
    expect(described_class.call("author/repo", "b4c0n", nil)).to be_nil

    expect(CoverageCheck.connection).not_to have_received(:execute).with(/pg_advisory_xact_lock/)
  end
end

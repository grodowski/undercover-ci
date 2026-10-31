# frozen_string_literal: true

require "rails_helper"

describe Logic::StartCheckRunFromUpload do
  let(:user) do
    User.create!(uid: "1337", email: "foo@bar.com", token: "sekritkey", name: "Foo Bar")
  end
  let(:installation) do
    Installation.create!(
      installation_id: "123123",
      users: [user],
      repos: [{"full_name" => "author/repo"}],
      settings: {"repo_fork_checks" => {"author/repo" => true}}
    )
  end
  let(:sha) { "b4c0n1" }

  subject { described_class.call("author/repo", sha, 42) }

  def stub_installation_token
    WebMock
      .stub_request(:post, "https://api.github.com/app/installations/123123/access_tokens")
      .to_return(status: 200, body: {token: "token"}.to_json, headers: {"Content-Type" => "application/json"})
  end

  def stub_pull_request_ref(head_sha: sha, status: 200)
    WebMock
      .stub_request(:get, "https://api.github.com/repos/author/repo/git/ref/pull/42/head")
      .to_return(
        status:,
        body: {ref: "refs/pull/42/head", object: {sha: head_sha}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_repository
    WebMock
      .stub_request(:get, "https://api.github.com/repos/author/repo")
      .to_return(
        status: 200,
        body: {
          id: 1,
          full_name: "author/repo",
          default_branch: "main",
          visibility: "public",
          private: false,
          html_url: "https://github.com/author/repo"
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  it "creates an awaiting_coverage CoverageCheck for a verified pull request head" do
    installation.itself
    stub_installation_token
    stub_pull_request_ref
    stub_repository

    Timecop.freeze do
      expect(subject).to eq(CoverageCheck.last)
      expect(ExpireCheckJob).to have_been_enqueued.at(120.minutes.from_now).with(subject.id)
    end

    coverage_check = CoverageCheck.last
    expect(coverage_check.state).to eq(:awaiting_coverage)
    expect(coverage_check.head_sha).to eq(sha)
    expect(coverage_check.base_sha).to be_nil
    expect(coverage_check.pull_request_number).to eq(42)
    expect(coverage_check.installation).to eq(installation)
    expect(coverage_check.repo).to eq(
      "id" => 1, "full_name" => "author/repo", "default_branch" => "main",
      "visibility" => "public", "private" => false, "html_url" => "https://github.com/author/repo"
    )
  end

  it "uses the installation that enabled fork checks when a stale one lists the repo too" do
    Installation.create!(installation_id: "999", users: [user], repos: [{"full_name" => "author/repo"}])
    installation.itself
    Installation.create!(installation_id: "998", users: [user], repos: [{"full_name" => "author/repo"}])
    stub_installation_token
    stub_pull_request_ref
    stub_repository

    expect(subject.installation).to eq(installation)
  end

  context "with an expired license" do
    before do
      installation.subscription.update!(created_at: 30.days.ago)
      stub_installation_token
      stub_pull_request_ref
    end

    it "does nothing for a private repo, whose upload would be rejected" do
      WebMock.stub_request(:get, "https://api.github.com/repos/author/repo").to_return(
        status: 200,
        body: {full_name: "author/repo", default_branch: "main", visibility: "private"}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

      expect { subject }.not_to change(CoverageCheck, :count)
    end

    it "creates a check for a public repo" do
      stub_repository

      expect { subject }.to change(CoverageCheck, :count).by(1)
    end
  end

  it "creates a check for a same-repo pull request whose check_suite webhook never arrived" do
    installation.itself
    stub_installation_token
    stub_pull_request_ref
    stub_repository

    expect { subject }.to change(CoverageCheck, :count).by(1)
    expect(WebMock).not_to have_requested(:get, /branches-where-head/)
  end

  context "with a pull request base ref" do
    subject { described_class.call("author/repo", sha, 42, "develop") }

    before do
      installation.itself
      stub_installation_token
      stub_pull_request_ref
      stub_repository
    end

    def stub_branch(status)
      WebMock.stub_request(:get, "https://api.github.com/repos/author/repo/branches/develop")
             .to_return(status:, body: {name: "develop"}.to_json, headers: {"Content-Type" => "application/json"})
    end

    it "stores the target branch as the compare base" do
      stub_branch(200)

      expect(subject.base_sha).to eq("develop")
      expect(DataObjects::CheckRunInfo.from_coverage_check(subject).compare).to eq("develop")
    end

    it "falls back to the default branch when the repo has no such branch" do
      stub_branch(404)
      allow(Rails.logger).to receive(:info)

      expect(subject.base_sha).to be_nil
      expect(DataObjects::CheckRunInfo.from_coverage_check(subject).compare).to eq("main")
      expect(Rails.logger).to have_received(:info)
        .with(a_string_including("against the default branch, base ref develop not found"))
    end

    it "does not look up the default branch" do
      expect(described_class.call("author/repo", sha, 42, "main").base_sha).to eq("main")
    end
  end

  context "with a branch filter" do
    before do
      installation.update!(repo_branch_filters: {"author/repo" => "^feature/"})
      stub_installation_token
      stub_pull_request_ref
      stub_repository
    end

    def stub_branches_where_head(names, status: 200)
      WebMock
        .stub_request(:get, "https://api.github.com/repos/author/repo/commits/#{sha}/branches-where-head")
        .to_return(
          status:,
          body: names.map { {name: it} }.to_json,
          headers: {"Content-Type" => "application/json"}
        )
    end

    it "creates a check for a fork's head, which is on no branch of the repo" do
      stub_branches_where_head([])

      expect { subject }.to change(CoverageCheck, :count).by(1)
    end

    it "creates a check for the head of a branch that matches the filter" do
      stub_branches_where_head(["feature/x"])

      expect { subject }.to change(CoverageCheck, :count).by(1)
    end

    it "does nothing for the head of a branch the filter excludes" do
      stub_branches_where_head(["dependabot/bundler/x"])

      expect { subject }.not_to change(CoverageCheck, :count)
    end

    it "does nothing when the branches cannot be listed" do
      stub_branches_where_head([], status: 500)

      expect { subject }.not_to change(CoverageCheck, :count)
    end
  end

  it "does nothing without a pull request number" do
    installation.itself

    expect { described_class.call("author/repo", sha, nil) }.not_to change(CoverageCheck, :count)
  end

  it "does nothing when no installation covers the repo" do
    expect { subject }.not_to change(CoverageCheck, :count)
  end

  it "does nothing when fork checks are disabled for the repo" do
    installation.update!(settings: {})

    expect { subject }.not_to change(CoverageCheck, :count)
  end

  it "does nothing when the sha is not the head of the pull request" do
    installation.itself
    stub_installation_token
    stub_pull_request_ref(head_sha: "s0me0ther5ha")

    expect { subject }.not_to change(CoverageCheck, :count)
  end

  it "does nothing when the pull request ref does not exist" do
    installation.itself
    stub_installation_token
    stub_pull_request_ref(status: 404)

    expect { subject }.not_to change(CoverageCheck, :count)
  end

  it "does nothing when the repository cannot be fetched" do
    installation.itself
    stub_installation_token
    stub_pull_request_ref
    WebMock.stub_request(:get, "https://api.github.com/repos/author/repo").to_return(status: 404)

    expect { subject }.not_to change(CoverageCheck, :count)
  end
end

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

    expect(subject).to eq(CoverageCheck.last)

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

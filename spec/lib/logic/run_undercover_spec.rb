# frozen_string_literal: true

require "rails_helper"

describe Logic::RunUndercover do
  before do
    # HACK: to allow testing git interactions in a repository that's not a git submodule
    # use fake.git as the preferred git-dir option inside spec/fixtures
    allow(Rugged::Repository).to receive(:new).and_wrap_original do |m, arg|
      m.call(arg + "/fake.git")
    end
    allow(Undercover::Changeset).to receive(:new).and_wrap_original do |m, (repo_path, compare)|
      m.call(repo_path.gsub(".git", ""), compare)
    end
  end

  let(:coverage_check) do
    CoverageCheck.create!(
      head_sha: "953a804", # commit sha from fake_repo fixture
      installation_id: "123123",
      repo: {"full_name" => "author/repo", "default_branch" => "master"},
      state: :awaiting_coverage
    )
  end
  subject { described_class.call(coverage_check) }

  it "raises a RunError if CoverageCheck is not in awaiting_coverage state" do
    coverage_check.update!(state: :created)

    expect { subject }.to raise_error(Logic::RunUndercover::RunError, /exiting early/)
  end

  it "raises a RunError if CoverageCheck has zero attached coverage reports" do
    expect { subject }.to raise_error(Logic::RunUndercover::RunError, /coverage_reports can't be blank/)
  end

  it "clones the repository and runs the undercover command" do
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )

    stub_get_installation_token
    check_runs_stub = stub_post_check_runs

    repo_path = "tmp/job/#{coverage_check.id}"
    expect(Imagen::Clone).to receive(:perform).with(
      "https://x-access-token:token@github.com/author/repo.git",
      repo_path
    ) do
      FileUtils.cp_r("spec/fixtures/fake_repo/.", repo_path) # fake clone, yay!
    end

    subject

    expect(coverage_check.reload.state).to eq(:complete)
    expect(check_runs_stub).to have_been_requested.twice
  end

  xit "stores a serialized Undercover::Report" do
    # pending "TODO: implement report persistence"
  end

  def stub_get_installation_token
    WebMock
      .stub_request(:post, "https://api.github.com/app/installations/123123/access_tokens")
      .to_return(
        status: 200,
        body: {token: "token"}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_post_check_runs
    WebMock
      .stub_request(:post, "https://api.github.com/repos/author/repo/check-runs")
      .to_return(status: 200, body: "", headers: {"Content-Type" => "application/json"})
  end
end

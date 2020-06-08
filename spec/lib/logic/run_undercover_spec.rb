# frozen_string_literal: true

require "rails_helper"

describe Logic::RunUndercover do
  let(:coverage_check) do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", users: [user])
    CoverageCheck.create!(
      installation: installation,
      head_sha: "b8f95245", # commit sha from fake_repo feature branch
      repo: {"full_name" => "author/repo", "default_branch" => "master"},
      state: :awaiting_coverage
    )
  end
  subject { described_class.call(coverage_check) }

  it "logs and returns when CoverageCheck is not in awaiting_coverage state" do
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )
    coverage_check.update!(state: :created)

    allow(Rails.logger).to receive(:info)
    expect(Rails.logger).to receive(:info).once.with(a_string_matching(/\[Logic::RunUndercover\] exiting early/))
    expect(subject).to be_nil
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
      FileUtils.cp_r("spec/fixtures/fake_repo/", repo_path) # fake clone, yay!
      # need to replace the git dir with a default name, since RunUndercover#run_undercover_cmd
      # does not respect custom git dirs
      FileUtils.mv(
        File.join(repo_path, "fake.git"),
        File.join(repo_path, ".git")
      )
    end

    subject

    expect(coverage_check.reload.state).to eq(:complete)
    expect(coverage_check.nodes.map(&:attributes).map(&:symbolize_keys)).to contain_exactly(
      hash_including(
        path: "foo.rb",
        node_type: "module",
        node_name: "Foo",
        start_line: 1,
        end_line: 11,
        coverage: 0.8333,
        flagged: false
      ),
      hash_including(
        path: "foo.rb",
        node_type: "instance method",
        node_name: "tested",
        start_line: 7,
        end_line: 10,
        coverage: 1.0,
        flagged: false
      ),
      hash_including(
        path: "foo.rb",
        node_type: "instance method",
        node_name: "untested",
        start_line: 2,
        end_line: 5,
        coverage: 0.5,
        flagged: true
      )
    )

    expect(check_runs_stub).to have_been_requested.twice
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

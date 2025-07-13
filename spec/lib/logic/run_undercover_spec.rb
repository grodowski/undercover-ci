# frozen_string_literal: true

require "rails_helper"

describe Logic::RunUndercover do
  include ActiveJob::TestHelper

  let(:coverage_check) do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", users: [user])
    CoverageCheck.create!(
      installation:,
      head_sha: "b8f95245", # commit sha from fake_repo feature branch
      repo: {"full_name" => "author/repo", "default_branch" => "master"},
      state: :in_progress
    )
  end
  subject { described_class.call(coverage_check) }

  it "logs and returns when CoverageCheck is not in in_progress state" do
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

  it "transitions a CoverageCheck from queued to in_progress" do
    coverage_check.update!(state: :queued)
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )

    # simulate a clone error, irrelevant for this test
    stub_get_installation_token
    stub_post_check_runs
    stub_fetch_merge_base
    allow(Git).to receive(:clone).and_raise(Git::Error)
    expect_any_instance_of(described_class).to receive(:teardown).once
    expect { subject }.to raise_error(Logic::RunUndercover::CloneError)

    # check that state has been updated
    expect(coverage_check.state).to eq(:in_progress)
  end

  it "raises a RunError if CoverageCheck has zero attached coverage reports" do
    expect { subject }.to raise_error(Logic::RunUndercover::RunError, /coverage_reports can't be blank/)
  end

  it "raises a CloneError when Git.clone fails to clone to trigger a retry" do
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )
    stub_get_installation_token
    stub_post_check_runs
    stub_fetch_merge_base
    allow(Git).to receive(:clone).and_raise(Git::Error)
    expect_any_instance_of(described_class).to receive(:teardown).once

    expect { subject }.to raise_error(Logic::RunUndercover::CloneError)
  end

  it "raises a CheckoutError when rugged fails to initialize to trigger a retry" do
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )
    stub_get_installation_token
    stub_post_check_runs
    stub_fetch_merge_base
    allow(Git).to receive(:clone) { double("Git::Base", fetch: true) }
    expect_any_instance_of(described_class).to receive(:teardown).once
    allow(Rugged::Repository).to receive(:new).and_raise(Rugged::OSError)

    expect { subject }.to raise_error(Logic::RunUndercover::CheckoutError)
  end

  it "logs when GitHub API fails to fetch the merge base" do
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )
    stub_get_installation_token
    stub_post_check_runs
    stub_fetch_merge_base_error
    allow(Rails.logger).to receive(:info)
    expect(Rails.logger).to receive(:info)
      .once
      .with(a_string_matching(/\[Logic::RunUndercover\] update_compare_to_merge_base failed/))
    expect_any_instance_of(described_class).to receive(:teardown).once

    expect { subject }.to raise_error(Octokit::ServiceUnavailable)
  end

  it "clones the repository and runs the undercover command" do
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )

    stub_get_installation_token
    stub_fetch_merge_base
    check_runs_stub = stub_post_check_runs

    repo_path = "tmp/job/#{coverage_check.id}"
    expect(Git).to receive(:clone).with(
      "https://x-access-token:token@github.com/author/repo.git",
      repo_path,
      depth: 1
    ) do
      FileUtils.cp_r("spec/fixtures/fake_repo/", repo_path) # fake clone, yay!
      # need to replace the git dir with a default name, since RunUndercover#run_undercover_cmd
      # does not respect custom git dirs
      FileUtils.mv(
        File.join(repo_path, "fake.git"),
        File.join(repo_path, ".git")
      )
      double("Git::Base", fetch: true)
    end

    subject

    coverage_check.reload
    expect(coverage_check.state).to eq(:complete)
    expect(coverage_check.result).to eq(:failed)
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

  it "handles JSON coverage reports" do
    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.json"),
      filename: "#{coverage_check.id}_b4c0n.json",
      content_type: "application/json"
    )

    stub_get_installation_token
    stub_fetch_merge_base
    check_runs_stub = stub_post_check_runs

    repo_path = "tmp/job/#{coverage_check.id}"
    expect(Git).to receive(:clone).with(
      "https://x-access-token:token@github.com/author/repo.git",
      repo_path,
      depth: 1
    ) do
      FileUtils.cp_r("spec/fixtures/fake_repo/", repo_path)
      FileUtils.mv(
        File.join(repo_path, "fake.git"),
        File.join(repo_path, ".git")
      )
      double("Git::Base", fetch: true)
    end

    subject

    coverage_check.reload
    expect(coverage_check.state).to eq(:complete)
    expect(check_runs_stub).to have_been_requested.twice
  end

  it "cancels the check on ReferenceError and returns a helpful error message" do
    allow(Rugged::Repository).to receive(:new)
      .and_raise(Rugged::ReferenceError, "revspec 'main' not found")

    coverage_check.coverage_reports.attach(
      io: File.open("spec/fixtures/coverage.lcov"),
      filename: "#{coverage_check.id}_b4c0n.lcov",
      content_type: "text/plain"
    )

    stub_get_installation_token
    check_runs_stub = stub_post_check_runs
    stub_fetch_merge_base
    expect_any_instance_of(described_class).to receive(:clone_repo).once
    expect_any_instance_of(described_class).to receive(:teardown).once

    perform_enqueued_jobs { subject }

    expect(coverage_check.reload.state).to eq(:canceled)
    expect(check_runs_stub).to have_been_requested.twice

    expect(WebMock).to have_requested(:post, "https://api.github.com/repos/author/repo/check-runs")
      .with(body: /revspec 'main' not found/).times(1)
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

  def stub_fetch_merge_base
    compare_json = {
      # actual commits from spec/fixtures/fake_repo
      base_commit: {sha: "dce6e1e942a782506dd37eda819dead236c112da"},
      merge_base_commit: {sha: "953a8049abaaa57f8db4ff97a55114283355d17e"}
    }.to_json

    WebMock
      .stub_request(:get, /https:\/\/api.github.com\/repos\/author\/repo\/compare\/\w+\.\.\.\w+/)
      .to_return(status: 200, body: compare_json, headers: {"Content-Type" => "application/json"})
  end

  def stub_fetch_merge_base_error
    WebMock
      .stub_request(:get, /https:\/\/api.github.com\/repos\/author\/repo\/compare\/\w+\.\.\.\w+/)
      .to_return(status: 503)
  end

  describe "#build_undercover_options" do
    let(:runner) { described_class.new(coverage_check) }
    let(:repo_path) { "tmp/job/#{coverage_check.id}" }

    before do
      coverage_check.coverage_reports.attach(
        io: File.open("spec/fixtures/coverage.lcov"),
        filename: "#{coverage_check.id}_b4c0n.lcov",
        content_type: "text/plain"
      )
      FileUtils.mkdir_p(repo_path)
    end

    after do
      FileUtils.rm_rf(repo_path)
    end

    it "builds options without .undercover file" do
      opts = runner.__send__(:build_undercover_options)

      expect(opts.lcov).to eq(runner.instance_variable_get(:@coverage_tmpfile).path)
      expect(opts.path).to eq(repo_path)
      expect(opts.compare).to eq(runner.instance_variable_get(:@run).compare)
      expect(opts.max_warnings_limit).to eq(51)
    end

    it "respects .undercover file when present" do
      config_content = <<~CONFIG
        -r ruby24
        -w 25
        -f *.rb,*.rake
        -x test/*,spec/*
      CONFIG
      File.write(File.join(repo_path, ".undercover"), config_content)

      opts = runner.__send__(:build_undercover_options)

      expect(opts.syntax_version).to eq("ruby24")
      expect(opts.max_warnings_limit).to eq(51) # CI override
      expect(opts.glob_allow_filters).to eq(["*.rb", "*.rake"])
      expect(opts.glob_reject_filters).to eq(["test/*", "spec/*"])
    end

    it "overrides CI-controlled options from .undercover file" do
      config_content = <<~CONFIG
        -c origin/main
        -l different.lcov
        -s different.json
        -p /some/path
        -g /some/git/dir
        -r ruby25
        -w 10
      CONFIG
      File.write(File.join(repo_path, ".undercover"), config_content)

      opts = runner.__send__(:build_undercover_options)

      expect(opts.compare).to eq(runner.instance_variable_get(:@run).compare)
      expect(opts.lcov).to eq(runner.instance_variable_get(:@coverage_tmpfile).path)
      expect(opts.path).to eq(repo_path)
      expect(opts.max_warnings_limit).to eq(51)
      expect(opts.syntax_version).to eq("ruby25")
    end

    it "handles .undercover file with only CI-controlled options" do
      config_content = <<~CONFIG
        -c origin/main
        -l different.lcov
        -p /some/path
      CONFIG
      File.write(File.join(repo_path, ".undercover"), config_content)

      opts = runner.__send__(:build_undercover_options)

      expect(opts.compare).to eq(runner.instance_variable_get(:@run).compare)
      expect(opts.lcov).to eq(runner.instance_variable_get(:@coverage_tmpfile).path)
      expect(opts.path).to eq(repo_path)
    end

    it "handles JSON coverage format" do
      coverage_check.coverage_reports.first.destroy
      coverage_check.coverage_reports.attach(
        io: File.open("spec/fixtures/coverage.json"),
        filename: "#{coverage_check.id}_b4c0n.json",
        content_type: "application/json"
      )

      runner_json = described_class.new(coverage_check)
      FileUtils.mkdir_p("tmp/job/#{coverage_check.id}")

      opts = runner_json.__send__(:build_undercover_options)

      expect(opts.simplecov_resultset).to eq(runner_json.instance_variable_get(:@coverage_tmpfile).path)
      expect(opts.lcov).to be_nil

      FileUtils.rm_rf("tmp/job/#{coverage_check.id}")
    end
  end
end

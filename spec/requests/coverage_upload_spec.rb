# frozen_string_literal: true

require "base64"
require "rails_helper"

describe "Coverage Upload" do
  let(:path) { "/v1/coverage.json" }

  it "renders 404 with a not_installed code for a repo UndercoverCI isn't installed on" do
    post path, params: {repo: "foo/bar", sha: "b4c0n"}

    expect(response.status).to eq(404)
    expect(response.parsed_body).to eq(
      "error" => "UndercoverCI is not installed on foo/bar", "code" => "not_installed"
    )
  end

  it "renders a plain 404 when an installed repo has no check for the commit" do
    user = User.create!(uid: "1337", email: "foo@bar.com", token: "sekritkey", name: "Foo Bar")
    Installation.create!(installation_id: "123123", users: [user], repos: [{"full_name" => "foo/bar"}])

    post path, params: {repo: "foo/bar", sha: "b4c0n"}

    expect(response.status).to eq(404)
    expect(response.parsed_body).to eq("error" => "No coverage check for b4c0n in foo/bar")
  end

  it "creates a check for a fork pull request when the upload carries a verified pull request number" do
    user = User.create!(uid: "1337", email: "foo@bar.com", token: "sekritkey", name: "Foo Bar")
    Installation.create!(
      installation_id: "123123",
      users: [user],
      repos: [{"full_name" => "user/repository"}]
    )
    stub_installation_token
    stub_pull_request_ref
    stub_repository
    contents = File.read("spec/fixtures/coverage.lcov")

    post path,
         params: {
           repo: "user/repository",
           sha: "b4c0n",
           pull_request_number: "42",
           lcov_base64: Base64.encode64(contents)
         }

    expect(response.status).to eq(201)
    check = CoverageCheck.last
    expect(check.pull_request_number).to eq(42)
    expect(check.state).to eq(:queued)
    expect(check.coverage_reports).not_to be_empty
    expect(check.base_sha).to be_nil
  end

  context "with a pull request base ref" do
    before do
      user = User.create!(uid: "1337", email: "foo@bar.com", token: "sekritkey", name: "Foo Bar")
      Installation.create!(
        installation_id: "123123",
        users: [user],
        repos: [{"full_name" => "user/repository"}]
      )
      stub_installation_token
      stub_pull_request_ref
      stub_repository
      %w[release%2F1.x release%2Bhotfix r%C3%A9lease].each do |branch|
        WebMock.stub_request(:get, "https://api.github.com/repos/user/repository/branches/#{branch}")
               .to_return(status: 200, body: "{}", headers: {"Content-Type" => "application/json"})
      end
    end

    def upload(params)
      post path, params: {
        repo: "user/repository",
        sha: "b4c0n",
        lcov_base64: Base64.encode64(File.read("spec/fixtures/coverage.lcov")),
        **params
      }
    end

    it "compares the check against the pull request's target branch" do
      upload(pull_request_number: "42", pull_request_base_ref: "release/1.x", pull_request_head_ref: "fix/typo")

      expect(response.status).to eq(201)
      expect(CoverageCheck.last.base_sha).to eq("release/1.x")
      expect(CoverageCheck.last.head_branch).to eq("fix/typo")
    end

    it "ignores an invalid head ref" do
      upload(pull_request_number: "42", pull_request_head_ref: "../main")

      expect(response.status).to eq(201)
      expect(CoverageCheck.last.head_branch).to be_nil
    end

    ["release+hotfix", "rélease"].each do |base_ref|
      it "accepts the git branch name #{base_ref}" do
        upload(pull_request_number: "42", pull_request_base_ref: base_ref)

        expect(response.status).to eq(201)
        expect(CoverageCheck.last.base_sha).to eq(base_ref)
      end
    end

    [
      "../main",
      "-main",
      "main.lock",
      "a b",
      "a~b",
      "@{-1}",
      "a\u0000b",
      "x" * 256,
      {"nested" => "main"},
      ["main"]
    ].each do |base_ref|
      it "ignores the invalid base ref #{base_ref.inspect[0, 20]}" do
        upload(pull_request_number: "42", pull_request_base_ref: base_ref)

        expect(response.status).to eq(201)
        expect(CoverageCheck.last.base_sha).to be_nil
      end
    end

    it "ignores the base ref without a pull request number" do
      upload(pull_request_base_ref: "release/1.x")

      expect(response.status).to eq(404)
      expect(CoverageCheck.count).to eq(0)
    end
  end

  it "rate limits uploads per repository and IP with a 429" do
    # rate_limit keeps the controller's cache store, a null store in test
    counters = ActiveSupport::Cache::MemoryStore.new
    allow(V1::CoverageReportsController.cache_store).to receive(:increment) do |*args, **opts|
      counters.increment(*args, **opts)
    end
    limit = CoverageUploadRateLimit::UPLOADS_PER_MINUTE

    limit.times { post path, params: {repo: "user/repository", sha: "b4c0n"} }
    expect(response.status).to eq(404)

    post path, params: {repo: "user/repository", sha: "b4c0n"}
    expect(response.status).to eq(429)
    expect(response.parsed_body["error"]).to include("Too many coverage uploads")

    delete path, params: {repo: "user/repository", sha: "b4c0n"}
    expect(response.status).to eq(429)

    post path, params: {repo: "user/other", sha: "b4c0n"}
    expect(response.status).to eq(404)
  end

  ["0", "-1", "4x", "9999999999", {"nested" => "42"}].each do |number|
    it "ignores the pull request number #{number.inspect}" do
      expect(Logic::StartCheckRunFromUpload).not_to receive(:call)

      post path, params: {repo: "user/repository", sha: "b4c0n", pull_request_number: number}

      expect(response.status).to eq(404)
    end
  end

  it "saves a verified pull request number on an existing check that has none" do
    check = make_coverage_check
    stub_installation_token
    stub_pull_request_ref

    post path,
         params: {
           repo: check.repo_full_name,
           sha: check.head_sha,
           pull_request_number: "42",
           lcov_base64: Base64.encode64(File.read("spec/fixtures/coverage.lcov"))
         }

    expect(response.status).to eq(201)
    expect(check.reload.pull_request_number).to eq(42)
  end

  it "renders 404 when a fork upload cannot be verified against the pull request head" do
    user = User.create!(uid: "1337", email: "foo@bar.com", token: "sekritkey", name: "Foo Bar")
    Installation.create!(
      installation_id: "123123",
      users: [user],
      repos: [{"full_name" => "user/repository"}]
    )
    stub_installation_token
    stub_pull_request_ref(head_sha: "n0tthesame")

    post path, params: {repo: "user/repository", sha: "b4c0n", pull_request_number: "42"}

    expect(response.status).to eq(404)
    expect(CoverageCheck.count).to eq(0)
  end

  it "does not create a check on delete" do
    delete path, params: {repo: "user/repository", sha: "b4c0n", pull_request_number: "42"}

    expect(response.status).to eq(404)
    expect(CoverageCheck.count).to eq(0)
  end

  it "stores the LCOV in active storage" do
    check = make_coverage_check
    contents = File.read("spec/fixtures/coverage.lcov")

    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    check.reload
    expect(check.coverage_reports).not_to be_empty

    expect(check.coverage_reports.attachments.first.download).to eq(contents)
    expect(response.status).to eq(201)
  end

  it "stores JSON coverage in active storage" do
    check = make_coverage_check
    contents = File.read("spec/fixtures/coverage.json")

    post path,
         params: {
           repo: check.repo_full_name,
           sha: check.head_sha,
           file_base64: Base64.encode64(contents),
           file_type: "json"
         }

    check.reload
    expect(check.coverage_reports).not_to be_empty

    expect(check.coverage_reports.attachments.first.download).to eq(contents)
    expect(check.coverage_reports.attachments.first.filename.to_s).to end_with(".json")
    expect(response.status).to eq(201)
  end

  it "validates uploads" do
    check = make_coverage_check
    contents = File.read("public/404.html") # text/html, should fail

    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)).to eq(
      "error" => "could not recognise '<!doctype html>\n' as valid LCOV"
    )
    expect(check.reload.coverage_reports.attached?).to eq(false)
  end

  it "validates JSON uploads" do
    check = make_coverage_check
    contents = "invalid json content"

    post path,
         params: {
           repo: check.repo_full_name,
           sha: check.head_sha,
           file_base64: Base64.encode64(contents),
           file_type: "json"
         }

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)["error"]).to include("Invalid JSON format")
    expect(check.reload.coverage_reports.attached?).to eq(false)
  end

  it "validates JSON uploads for basic expected formatter schema" do
    contents = nil
    check = make_coverage_check
    do_post = proc do
      post path,
           params: {
             repo: check.repo_full_name,
             sha: check.head_sha,
             file_base64: Base64.encode64(contents),
             file_type: "json"
           }
    end

    contents = {}.to_json
    do_post.call

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)["error"]).to eq(
      "Missing JSON keys: meta, coverage. Did you use SimpleCov::Formatter::Undercover?"
    )
    expect(check.reload.coverage_reports.attached?).to eq(false)

    contents = {meta: {simplecov_root: ""}}.to_json
    do_post.call

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)["error"]).to eq(
      "Missing JSON keys: coverage. Did you use SimpleCov::Formatter::Undercover?"
    )
    expect(check.reload.coverage_reports.attached?).to eq(false)

    contents = {meta: {}, coverage: {"foo.rb" => {}}}.to_json
    do_post.call

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)["error"]).to eq(
      "Missing/malformed coverage data. Did you use SimpleCov::Formatter::Undercover?"
    )
    expect(check.reload.coverage_reports.attached?).to eq(false)
  end

  it "accepts coverage even though the check has been canceled" do
    check = make_coverage_check
    check.update!(state: :canceled)

    contents = File.read("spec/fixtures/coverage.lcov")
    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    expect(response.status).to eq(201)

    expect(check.reload.coverage_reports.attached?).to eq(true)
    expect(check.reload.state).to eq(:queued)
  end

  it "transitions the check to in_progress and enqueues RunUndercover in 5 seconds" do
    check = make_coverage_check
    contents = File.read("spec/fixtures/coverage.lcov")

    Timecop.freeze do
      expect do
        post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}
      end.to have_enqueued_job(RunnerJob).at(5.seconds.from_now)
    end

    expect(check.reload.state).to eq(:queued)
    expect(response.status).to eq(201)
  end

  it "restarts an in_progress check and enqueues RunUndercover in 5 seconds" do
    check = make_coverage_check
    check.update!(state: :in_progress)
    contents = File.read("spec/fixtures/coverage.lcov")

    Timecop.freeze do
      expect do
        post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}
      end.to have_enqueued_job(RunnerJob).at(5.seconds.from_now)
    end

    expect(check.reload.state).to eq(:queued)
    expect(response.status).to eq(201)
  end

  it "fails when installation is inactive" do
    check = make_coverage_check
    check.update!(state: :in_progress)
    Subscription.create!(
      installation: check.installation,
      state: :unsubscribed,
      end_date: 1.day.ago,
      gumroad_id: "subxxx",
      license_key: "1337"
    )

    contents = File.read("spec/fixtures/coverage.lcov")
    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    expect(check.reload.state).to eq(:in_progress) # canceled?
    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)).to eq(
      "error" => "Your UndercoverCI license has expired, visit https://undercover-ci.com/settings to subscribe."
    )
  end

  it "allows public repos with an inactive subscription" do
    check = make_coverage_check
    check.state = :in_progress
    check.repo["visibility"] = "public"
    check.save!
    Subscription.create!(
      installation: check.installation,
      state: :unsubscribed,
      end_date: 1.day.ago,
      gumroad_id: "subxxx",
      license_key: "1337"
    )

    contents = File.read("spec/fixtures/coverage.lcov")
    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    expect(check.reload.state).to eq(:queued)
    expect(response.status).to eq(201)
  end

  it "raises a state machine error when check is complete" do
    check = make_coverage_check
    check.update!(state: :complete)
    contents = "SF:./foo.rb\nDA:1,1"

    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)).to eq(
      "error" => "Coverage check #{check.id} has already completed. Please push a new commit to restart."
    )
  end

  it "kicks off RunUndercover" do
    # can't test set(wait: 5.seconds) with inline adapter
    allow(RunnerJob).to receive(:set) { RunnerJob }

    check = make_coverage_check
    contents = File.read("spec/fixtures/coverage.lcov")

    fake_run = class_spy(Logic::RunUndercover)
    stub_const("Logic::RunUndercover", fake_run)

    perform_enqueued_jobs do
      post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}
    end

    expect(response.status).to eq(201)
    expect(fake_run).to have_received(:call)
  end

  describe "#destroy" do
    it "transitions the CoverageCheck to cancelled" do
      check = make_coverage_check

      expect_any_instance_of(CheckRuns::Canceled).to receive(:post).once

      delete path, params: {repo: check.repo_full_name, sha: check.head_sha}

      expect(response.status).to eq(204)
      expect(check.reload.state).to eq(:canceled)
    end

    it "returns a 404 if the check does not exist" do
      delete path, params: {repo: "user/repository", sha: "b4c0n"}

      expect(response.status).to eq(404)
    end
  end

  def stub_installation_token
    WebMock
      .stub_request(:post, "https://api.github.com/app/installations/123123/access_tokens")
      .to_return(status: 200, body: {token: "token"}.to_json, headers: {"Content-Type" => "application/json"})
  end

  def stub_pull_request_ref(head_sha: "b4c0n")
    WebMock
      .stub_request(:get, "https://api.github.com/repos/user/repository/git/ref/pull/42/head")
      .to_return(
        status: 200,
        body: {ref: "refs/pull/42/head", object: {sha: head_sha}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_repository
    WebMock
      .stub_request(:get, "https://api.github.com/repos/user/repository")
      .to_return(
        status: 200,
        body: {id: 1, full_name: "user/repository", default_branch: "main", visibility: "public"}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def make_coverage_check
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", users: [user])
    CoverageCheck.create!(
      state: :awaiting_coverage,
      installation:,
      repo: {id: 1, full_name: "user/repository"},
      head_sha: "b4c0n"
    )
  end
end

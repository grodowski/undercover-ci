# frozen_string_literal: true

require "base64"
require "rails_helper"

describe "Coverage Upload" do
  # FIXME: authenticate
  def path
    "/v1/coverage.json"
  end

  it "renders 404 when CoverageCheck does not exist" do
    expect { post path, params: {repo: "foo", sha: "bar"} }.to raise_error(ActiveRecord::RecordNotFound)
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

  it "validates uploads" do
    check = make_coverage_check
    contents = File.read("public/404.html") # text/html, should fail

    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)).to eq(
      "error" => "could not recognise '<!DOCTYPE html>\n' as valid LCOV"
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
    expect(check.reload.state).to eq(:in_progress)
  end

  it "transitions the check to in_progress and enqueues RunUndercover in 5 seconds" do
    check = make_coverage_check
    contents = File.read("spec/fixtures/coverage.lcov")

    Timecop.freeze do
      expect do
        post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}
      end.to have_enqueued_job(RunnerJob).at(5.seconds.from_now)
    end

    expect(check.reload.state).to eq(:in_progress)
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

    expect(check.reload.state).to eq(:in_progress)
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

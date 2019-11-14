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

    fake_run = class_spy(Logic::RunUndercover)
    stub_const("Logic::RunUndercover", fake_run)

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

  it "kicks off RunUndercover", inline_jobs: true do
    check = make_coverage_check
    contents = File.read("spec/fixtures/coverage.lcov")

    fake_run = class_spy(Logic::RunUndercover)
    stub_const("Logic::RunUndercover", fake_run)

    post path, params: {repo: check.repo_full_name, sha: check.head_sha, lcov_base64: Base64.encode64(contents)}

    expect(fake_run).to have_received(:call)
  end

  def make_coverage_check
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", user: user)
    CoverageCheck.create!(installation: installation, repo: {id: 1, full_name: "user/repository"}, head_sha: "b4c0n")
  end
end

# frozen_string_literal: true

require "rails_helper"
require_relative "../public/uploader"

describe "uploader.rb" do
  def build_uploader(arg_str)
    UndercoverCiCoverageUpload.new(arg_str.split)
  end

  def with_env(vars)
    previous = ENV.to_h.slice(*vars.keys)
    vars.each { |name, value| ENV[name] = value }
    yield
  ensure
    vars.each_key { |name| ENV.delete(name) }
    previous.each { |name, value| ENV[name] = value }
  end

  def stub_post_coverage(payload, status: 201)
    WebMock
      .stub_request(:post, "https://undercover-ci.com/v1/coverage")
      .to_return(
        status:,
        body: JSON.generate(payload), # do not escape utf-8 with to_json
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_delete_coverage(payload, status: 204)
    WebMock
      .stub_request(:delete, "https://undercover-ci.com/v1/coverage")
      .to_return(
        status:,
        body: JSON.generate(payload), # do not escape utf-8 with to_json
        headers: {"Content-Type" => "application/json"}
      )
  end

  it "exits 1 and prints usage with empty args" do
    expected_banner = "Usage: ruby -e \"$(curl -s https://undercover-ci.com/uploader.rb)\" -- [options]"
    expect do
      uploader = build_uploader("")
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(a_string_including(expected_banner)).to_stderr
  end

  it "prints the server error message on error" do
    stub_post_coverage(
      {"error" => "could not recognise '<!DOCTYPE html>' as valid LCOV"},
      status: 422
    )
    expect do
      uploader = build_uploader("--lcov spec/fixtures/coverage.lcov --repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(
      a_string_including("Error 422, {\"error\":\"could not recognise '<!DOCTYPE html>' as valid LCOV\"")
    ).to_stderr
  end

  it "exits 1 when supplied coverage report is empty" do
    expect do
      uploader = build_uploader("--lcov spec/fixtures/empty_coverage.lcov --repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(
      a_string_including("spec/fixtures/empty_coverage.lcov is an empty file, is that the correct path?")
    ).to_stderr
  end

  it "validates that either lcov or simplecov is provided" do
    expect do
      uploader = build_uploader("--repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(a_string_including("Usage:")).to_stderr
  end

  it "exits 1 when supplied SimpleCov JSON report is empty" do
    allow(File).to receive(:read).with("spec/fixtures/empty_coverage.json").and_return("")
    expect do
      uploader = build_uploader("--simplecov spec/fixtures/empty_coverage.json --repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(
      a_string_including("spec/fixtures/empty_coverage.json is an empty file, is that the correct path?")
    ).to_stderr
  end

  it "handles 404 when check is not found" do
    stub_post_coverage({"error" => "record not found"}, status: 404)
    expect do
      uploader = build_uploader("--lcov spec/fixtures/coverage.lcov --repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(
      a_string_including("Error 404: does a check for commit 1fffbb exist in alice/bob?")
    ).to_stderr
  end

  it "prints 201 on success" do
    stub_post_coverage({}, status: 201)
    expect do
      uploader = build_uploader("--lcov spec/fixtures/coverage.lcov --repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(0)
    end.to output(a_string_ending_with("Done! 201\n")).to_stdout

    expect(
      a_request(:post, "https://undercover-ci.com/v1/coverage")
      .with(
        body: JSON.generate(
          repo: "alice/bob",
          sha: "1fffbb",
          file_base64: Base64.strict_encode64(File.read("spec/fixtures/coverage.lcov")),
          file_type: "lcov"
        )
      )
    ).to have_been_made
  end

  it "sends the pull request number when --pull-request is given" do
    stub_post_coverage({}, status: 201)
    expect do
      uploader = build_uploader(
        "--lcov spec/fixtures/coverage.lcov --repo alice/bob --commit 1fffbb --pull-request 42"
      )
      uploader.upload
      expect(uploader.exitcode).to eq(0)
    end.to output(a_string_ending_with("Done! 201\n")).to_stdout

    expect(
      a_request(:post, "https://undercover-ci.com/v1/coverage")
      .with(
        body: JSON.generate(
          repo: "alice/bob",
          sha: "1fffbb",
          file_base64: Base64.strict_encode64(File.read("spec/fixtures/coverage.lcov")),
          file_type: "lcov",
          pull_request_number: "42"
        )
      )
    ).to have_been_made
  end

  it "omits the pull request number when --pull-request expands to nothing" do
    stub_post_coverage({}, status: 201)
    uploader = build_uploader(
      "--pull-request --simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb"
    )
    expect(uploader.options.pull_request).to be_nil

    uploader.upload
    expect(uploader.exitcode).to eq(0)

    expect(
      a_request(:post, "https://undercover-ci.com/v1/coverage")
      .with { |req| !JSON.parse(req.body).key?("pull_request_number") }
    ).to have_been_made
  end

  it "exits 1 when --pull-request is not a number" do
    expect do
      uploader = build_uploader(
        "--pull-request b4c0n --simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb"
      )
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(a_string_including("--pull-request must be a number")).to_stderr

    expect(a_request(:post, "https://undercover-ci.com/v1/coverage")).not_to have_been_made
  end

  it "warns on a pull request build without --pull-request" do
    stub_post_coverage({}, status: 201)

    with_env("GITHUB_REF" => "refs/pull/42/merge") do
      expect do
        uploader = build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb")
        uploader.upload
        expect(uploader.exitcode).to eq(0)
      end.to output(a_string_including("build of pull request #42, but --pull-request was not set")).to_stderr
    end
  end

  it "does not warn when --pull-request is set" do
    stub_post_coverage({}, status: 201)

    with_env("GITHUB_REF" => "refs/pull/42/merge") do
      expect do
        build_uploader(
          "--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb --pull-request 42"
        ).upload
      end.not_to output.to_stderr
    end
  end

  it "does not warn on a push build" do
    stub_post_coverage({}, status: 201)

    with_env("GITHUB_REF" => "refs/heads/main") do
      expect do
        build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb").upload
      end.not_to output.to_stderr
    end
  end

  it "uploads SimpleCov JSON coverage successfully" do
    stub_post_coverage({}, status: 201)
    expect do
      uploader = build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(0)
    end.to output("Done! 201\n").to_stdout

    expect(
      a_request(:post, "https://undercover-ci.com/v1/coverage")
      .with(
        body: JSON.generate(
          repo: "alice/bob",
          sha: "1fffbb",
          file_base64: Base64.strict_encode64(File.read("spec/fixtures/coverage.json")),
          file_type: "json"
        )
      )
    ).to have_been_made
  end

  it "accepts --cancel to cancel a check" do
    stub_delete_coverage({}, status: 204)
    expect do
      uploader = build_uploader("--cancel --repo alice/bob --commit 1fffbb")
      uploader.cancel
      expect(uploader.exitcode).to eq(0)
    end.to output("Done! 204\n").to_stdout

    expect(
      a_request(:delete, "https://undercover-ci.com/v1/coverage")
      .with(
        body: JSON.generate(
          repo: "alice/bob",
          sha: "1fffbb"
        )
      )
    ).to have_been_made
  end
end

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

  around do |example|
    with_env(
      "GITHUB_ACTIONS" => nil, "GITHUB_REPOSITORY" => nil,
      "GITHUB_REF" => nil, "GITHUB_BASE_REF" => nil, "GITHUB_HEAD_REF" => nil
    ) do
      example.run
    end
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

  it "prints the server error message when rate limited" do
    stub_post_coverage({"error" => "Too many coverage uploads"}, status: 429)
    expect do
      uploader = build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb")
      uploader.upload
      expect(uploader.exitcode).to eq(1)
    end.to output(a_string_including("Error 429, {\"error\":\"Too many coverage uploads\"}")).to_stderr
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

  context "when running in a different repository, like a contributor's fork" do
    around { |example| with_env("GITHUB_REPOSITORY" => "someone/bob-fork") { example.run } }

    def upload
      build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb").tap(&:upload)
    end

    it "uploads to the repository it runs in" do
      stub_post_coverage({}, status: 201)

      expect { expect(upload.exitcode).to eq(0) }
        .to output(a_string_including("Running in someone/bob-fork, uploading coverage there instead of alice/bob"))
        .to_stdout
      expect(uploaded_body).to include("repo" => "someone/bob-fork")
    end

    it "prints a setup notice and succeeds when UndercoverCI isn't set up there" do
      stub_post_coverage({"error" => "not installed", "code" => "not_installed"}, status: 404)

      expect { expect(upload.exitcode).to eq(0) }
        .to output(
          a_string_including(
            "\nUndercoverCI isn't set up for someone/bob-fork, so coverage wasn't uploaded. " \
            "It's free for public repos: https://undercover-ci.com\n"
          )
        ).to_stdout
    end

    it "shows the setup notice on the run summary on GitHub Actions" do
      stub_post_coverage({"error" => "not installed", "code" => "not_installed"}, status: 404)

      expect { with_env("GITHUB_ACTIONS" => "true") { upload } }
        .to output(a_string_including("::notice title=UndercoverCI::UndercoverCI isn't set up for someone/bob-fork"))
        .to_stdout
    end

    it "fails on a 404 when UndercoverCI is installed there but has no check" do
      stub_post_coverage({"error" => "record not found"}, status: 404)

      expect { expect(upload.exitcode).to eq(1) }
        .to output(a_string_including("Error 404: does a check for commit 1fffbb exist in someone/bob-fork?"))
        .to_stderr
    end

    it "fails on a 404 that isn't from UndercoverCI" do
      WebMock.stub_request(:post, "https://undercover-ci.com/v1/coverage")
             .to_return(status: 404, body: "<html>Not Found</html>")

      expect { expect(upload.exitcode).to eq(1) }.to output(a_string_including("Error 404")).to_stderr
    end

    it "still fails on other errors" do
      stub_post_coverage({"error" => "license expired"}, status: 422)

      expect { expect(upload.exitcode).to eq(1) }.to output(a_string_including("Error 422")).to_stderr
    end

    it "cancels the check in the repository it runs in" do
      stub_delete_coverage({}, status: 204)

      expect do
        build_uploader("--repo alice/bob --commit 1fffbb --simplecov spec/fixtures/coverage.json --cancel").cancel
      end.to output.to_stdout
      expect(WebMock).to have_requested(:delete, "https://undercover-ci.com/v1/coverage")
        .with(body: hash_including("repo" => "someone/bob-fork"))
    end

    it "uploads to --repo when only the case differs" do
      stub_post_coverage({}, status: 201)

      with_env("GITHUB_REPOSITORY" => "Alice/Bob") { upload }

      expect(uploaded_body).to include("repo" => "alice/bob")
    end
  end

  it "uploads to a custom --url with a port" do
    WebMock.stub_request(:post, "http://localhost:3000/v1/coverage").to_return(status: 201)

    expect do
      build_uploader(
        "--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb " \
        "--url http://localhost:3000/v1/coverage"
      ).upload
    end.to output(a_string_including("Done! 201")).to_stdout
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
      uploader = with_env("GITHUB_BASE_REF" => nil) do
        build_uploader("--lcov spec/fixtures/coverage.lcov --repo alice/bob --commit 1fffbb --pull-request 42")
      end
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

  def uploaded_body
    body = nil
    expect(a_request(:post, "https://undercover-ci.com/v1/coverage").with { body = JSON.parse(it.body) })
      .to have_been_made
    body
  end

  it "sends --pull-request-base-ref with the pull request number" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_BASE_REF" => "main") do
      build_uploader(
        "--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb " \
        "--pull-request 42 --pull-request-base-ref release/1.x"
      ).upload
    end

    expect(uploaded_body).to include("pull_request_number" => "42", "pull_request_base_ref" => "release/1.x")
  end

  it "defaults the pull request base ref to GITHUB_BASE_REF" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_BASE_REF" => "develop") do
      build_uploader(
        "--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb " \
        "--pull-request 42 --pull-request-base-ref"
      ).upload
    end

    expect(uploaded_body).to include("pull_request_number" => "42", "pull_request_base_ref" => "develop")
  end

  it "sends --pull-request-head-ref with the pull request number" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_HEAD_REF" => "fix/typo") do
      build_uploader(
        "--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb " \
        "--pull-request 42 --pull-request-head-ref feature"
      ).upload
    end

    expect(uploaded_body).to include("pull_request_number" => "42", "pull_request_head_ref" => "feature")
  end

  it "defaults the pull request head ref to GITHUB_HEAD_REF" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_HEAD_REF" => "fix/typo") do
      build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb --pull-request 42")
        .upload
    end

    expect(uploaded_body).to include("pull_request_number" => "42", "pull_request_head_ref" => "fix/typo")
  end

  it "omits the pull request base ref without a pull request number" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_BASE_REF" => "develop") do
      build_uploader(
        "--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb --pull-request-base-ref main"
      ).upload
    end

    expect(uploaded_body.keys).not_to include("pull_request_number", "pull_request_base_ref", "pull_request_head_ref")
  end

  it "omits the pull request base ref when there is none" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_BASE_REF" => "") do
      build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb --pull-request 42")
        .upload
    end

    expect(uploaded_body).to include("pull_request_number" => "42")
    expect(uploaded_body).not_to have_key("pull_request_base_ref")
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

  it "detects the pull request number and base ref on a GitHub Actions pull request build" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_REF" => "refs/pull/42/merge", "GITHUB_BASE_REF" => "develop") do
      build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb").upload
    end

    expect(uploaded_body).to include("pull_request_number" => "42", "pull_request_base_ref" => "develop")
  end

  it "prefers an explicit --pull-request over the detected one" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_REF" => "refs/pull/42/merge") do
      build_uploader(
        "--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb --pull-request 7"
      ).upload
    end

    expect(uploaded_body).to include("pull_request_number" => "7")
  end

  it "sends no pull request number on a push build" do
    stub_post_coverage({}, status: 201)
    with_env("GITHUB_REF" => "refs/heads/main", "GITHUB_BASE_REF" => "") do
      build_uploader("--simplecov spec/fixtures/coverage.json --repo alice/bob --commit 1fffbb").upload
    end

    expect(uploaded_body.keys).not_to include("pull_request_number", "pull_request_base_ref")
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

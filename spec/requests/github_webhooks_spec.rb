# frozen_string_literal: true

require "rails_helper"

describe "GitHub Webhooks" do
  let(:path) { "/v1/hooks/" }

  def sign_hook(json)
    "sha1=#{OpenSSL::HMAC.hexdigest('sha1', 'sekrit', json)}"
  end

  it "requires application/json" do
    invalid_headers = {
      "CONTENT_TYPE": "text/html",
      "ACCEPT": "text/html"
    }

    expect do
      post path, headers: invalid_headers
    end.to raise_error(ActionController::RoutingError)
  end

  %w[invalid sha1=invalid asdf=invalid].each do |sig|
    it "is unauthorized when X_HUB_SIGNATURE is #{sig}" do
      invalid_headers = {
        "CONTENT_TYPE": "application/json",
        "ACCEPT": "application/json",
        "HTTP_X_HUB_SIGNATURE": sig
      }
      post path, params: "{}", headers: invalid_headers
      expect(response).to be_unauthorized
    end
  end

  it "returns ok for unhandled actions" do
    payload = {action: :start}.to_json
    valid_headers = {
      "ACCEPT": "application/json",
      "HTTP_X_HUB_SIGNATURE": sign_hook(payload),
      "HTTP_X_GITHUB_EVENT": "partyhard"
    }

    post path, params: payload, headers: valid_headers
    expect(response).to be_ok
  end

  xit "handles installations" do
    pending "Handle installation_repositories"
  end

  xit "handles installation_repositories" do
    pending "Handle installation_repositories"
  end

  it "handles check_suite and creates a new check_run" do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    Installation.create!(installation_id: 43_009_808, user: user)

    payload = {
      "action" => "requested",
      "check_suite" => {"head_sha" => "0fb234"},
      "installation" => {"id" => 43_009_808},
      "repository" => {"full_name" => "grodowski/undercover-ci"},
      "pull_requests" => []
    }
    valid_headers = {
      "ACCEPT": "application/json",
      "HTTP_X_HUB_SIGNATURE": sign_hook(payload.to_json),
      "HTTP_X_GITHUB_EVENT": "check_suite"
    }
    allow(CreateCheckRunJob).to receive(:perform_later)

    post path, params: payload.to_json, headers: valid_headers

    coverage_job = CoverageCheck.last
    expect(coverage_job.attributes).to include(
      "repo" => {"full_name" => "grodowski/undercover-ci"},
      "head_sha" => "0fb234"
    )

    expect(CreateCheckRunJob).to have_received(:perform_later)
      .with(coverage_job.id)
    expect(response).to be_ok
  end
end

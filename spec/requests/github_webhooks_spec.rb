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

  it "logs unhandled actions and returns ok" do
    payload = {action: :start}.to_json
    valid_headers = {
      "ACCEPT": "application/json",
      "HTTP_X_HUB_SIGNATURE": sign_hook(payload),
      "HTTP_X_GITHUB_EVENT": "partyhard"
    }

    expect(Rails.logger)
      .to receive(:debug)
      .with("Webhook Unhandled: start/partyhard")

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
    payload = {
      "action" => "requested",
      "check_suite" => {"head_sha" => "0fb234"},
      "installation" => {"id" => 43_009_808},
      "repository" => {"full_name" => "grodowski/undercover-ci"}
    }
    valid_headers = {
      "ACCEPT": "application/json",
      "HTTP_X_HUB_SIGNATURE": sign_hook(payload.to_json),
      "HTTP_X_GITHUB_EVENT": "check_suite"
    }

    expect(CreateCheckRunJob).to receive(:perform_later)
      .with(hash_including(payload.symbolize_keys))

    post path, params: payload.to_json, headers: valid_headers
    expect(response).to be_ok
  end
end

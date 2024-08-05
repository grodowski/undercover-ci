# frozen_string_literal: true

require "rails_helper"

describe "Settings" do
  let!(:user) do
    User.create!(
      uid: "1337",
      token: "t0k3n",
      email: "foo@undercover-ci.com",
      name: "foo"
    )
  end

  let(:github_installations) { [{id: "1337", target_type: "User"}] }
  before do
    stub_request(:get, "https://api.github.com/user/installations/1337/repositories?per_page=100")
      .to_return(
        status: 200,
        body: {
          repositories: [{id: 1, url: "https://api.github.com/repos/grodowski/undercover"}]
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )
    stub_request(:get, "https://api.github.com/user/installations?per_page=100")
      .to_return(
        status: 200,
        body: "{\"total_count\": 0, \"installations\": #{github_installations.to_json}}",
        headers: {"Content-Type" => "application/json"}
      )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  end

  it "resets user access token" do
    allow(SecureRandom).to receive(:hex) { String.new("s3krit") }
    get("/auth/github/callback")
    post("/settings/access_token")

    expect(response).to redirect_to(settings_path)

    get("/settings")
    body = response.body
    expect(body).to include("Ensure your user API token is stored securely.")
    expect(body).to include(
      "<input type=\"text\" class=\"form-control\" readonly " \
      "placeholder=\"No access token generated\" value=\"s3krit\"/>"
    )

    get("/v1/checks/notexists.json")
    expect(response.status).to eq(401)

    get("/v1/checks/notexists.json", headers: {HTTP_AUTHORIZATION: "Token token=s3krit"})
    expect(response.status).to eq(404)
  end
end

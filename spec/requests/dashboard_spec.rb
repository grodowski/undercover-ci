# frozen_string_literal: true

require "rails_helper"

describe "Dashboard spec" do
  let(:user) do
    User.create!(
      uid: "asd123",
      token: "t0k3n",
      email: "foo@undercover-ci.com",
      name: "foo"
    )
  end

  before do
    stub_request(:get, "https://api.github.com/user/installations?per_page=100")
      .to_return(
        status: 200,
        body: "{\"total_count\": 0, \"installations\": []}",
        headers: {"Content-Type" => "application/json"}
      )
  end

  it "renders dashboard#index for a signed in user" do
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
    get("/auth/github/callback")

    get("/app")
    expect(response).to redirect_to("/settings/new")
  end

  it "redirects to root url for an anonymous user" do
    expect(get("/app")).to redirect_to root_url
  end
end

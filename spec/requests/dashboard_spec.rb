# frozen_string_literal: true

require "rails_helper"

describe "Dashboard spec" do
  let(:user) do
    User.create!(
      uid: "1337",
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
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  end

  describe "GET /app" do
    it "renders dashboard#index for a signed in user" do
      get("/auth/github/callback")

      get("/app")
      expect(response).to redirect_to("/settings/new")
    end

    it "redirects to root url for an anonymous user" do
      expect(get("/app")).to redirect_to root_url
    end
  end

  describe "GET /checks/:id" do
    it "renders checks/show" do
      inst = Installation.create!(installation_id: 43_009_808, user: user)
      check = CoverageCheck.create!(head_sha: "1337SHA", installation: inst)

      get("/auth/github/callback")
      expect(get("/checks/#{check.id}")).to render_template("dashboard/checks/show")
    end
  end
end

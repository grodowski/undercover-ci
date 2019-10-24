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

  it "renders dashboard#index for a signed in user" do
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
    get("/auth/github/callback")

    get("/app")
    expect(response).to render_template("dashboard/index")
  end

  it "redirects to root url for an anonymous user" do
    expect(get("/app")).to redirect_to root_url
  end
end

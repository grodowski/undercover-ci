# frozen_string_literal: true

require "rails_helper"

describe "GitHub auth" do
  before { Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github] }

  it "creates a user and session" do
    expect do
      get "/auth/github/callback"
    end.to change(User, :count).from(0).to(1)

    expect(session[:user_id]).to eq(User.last.id)
  end

  it "creates a session for an existing user" do
    User.create!(uid: "1337", name: "Foo Bar", email: "foo@bar.com", token: "sekrit")

    expect do
      get "/auth/github/callback"
    end.not_to change(User, :count)

    expect(session[:user_id]).to eq(User.last.id)
  end

  xit "signs out a user" do
    # TODO: implement sign out
  end
end

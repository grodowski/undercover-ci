# frozen_string_literal: true

require "rails_helper"

describe "/beta" do
  before do
    @old_code = ENV["BETA_CODE"]
    ENV["BETA_CODE"] = "bacon"
  end
  after { ENV["BETA_CODE"] = @old_code }

  it "sets the beta_sign_in cookie" do
    get "/beta?x=bacon"
    expect(response.status).to eq(200)
    expect(cookies[:beta_sign_in]).to be_present
  end
end

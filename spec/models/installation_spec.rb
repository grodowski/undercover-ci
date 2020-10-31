# frozen_string_literal: true

require "rails_helper"

RSpec.describe Installation, type: :model do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("FF_SUBSCRIPTION") { "1" }
  end

  describe "create" do
    it "ensures a trial subscription for orgs" do
      user = User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo")
      installation = Installation.create!(
        installation_id: "123123", users: [user],
        metadata: {target_type: "Organization"}
      )

      expect(installation.subscription).to be_persisted
      expect(installation.subscription.attributes).to match(
        hash_including(
          "end_date" => nil,
          "gumroad_id" => nil,
          "license_key" => nil
        )
      )
    end
  end

  it "doesn't create a subscription for users" do
    user = User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo")
    installation = Installation.create!(
      installation_id: "123123", users: [user],
      metadata: {target_type: "User"}
    )

    expect(installation.subscription).to eq(nil)
  end
end

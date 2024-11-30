# frozen_string_literal: true

require "rails_helper"

RSpec.describe Installation, type: :model do
  let(:user) { User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo") }

  describe "create" do
    it "ensures a trial subscription for orgs" do
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
    installation = Installation.create!(
      installation_id: "123123", users: [user],
      metadata: {target_type: "User"}
    )

    expect(installation.subscription).to eq(nil)
  end

  it "allows setting max_concurrent_checks" do
    installation = Installation.create!(
      installation_id: "123123", users: [user],
      metadata: {target_type: "User"},
      settings: {max_concurrent_checks: 10}
    )
    expect(installation.max_concurrent_checks).to eq(10)
  end

  it "returns a default with empty settings #max_concurrent_checks" do
    installation = Installation.create!(
      installation_id: "123123", users: [user],
      metadata: {target_type: "User"}
    )
    stub_const("Installation::DEFAULT_MAX_CONCURRENT_CHECKS", 2)
    expect(installation.max_concurrent_checks).to eq(2)
  end
end

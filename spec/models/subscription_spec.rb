# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "#active?" do
    it "is true when beta" do
      expect(Subscription.new(state: :beta).active?).to eq(true)
    end

    it "is true when unsubscribed trial" do
      installation = Installation.create!(installation_id: "123123")
      subscription = Subscription.create!(
        state: :unsubscribed,
        installation: installation,
        gumroad_id: "subxxx",
        license_key: "1337"
      )

      expect(subscription.active?).to eq(true)
    end

    it "it true when subscribed" do
      expect(Subscription.new(state: :subscribed).active?).to eq(true)
    end

    it "is false when unsubscribed goes past trial period" do
      subscription = Subscription.new(state: :unsubscribed, created_at: 15.days.ago)

      expect(subscription.active?).to eq(false)
    end

    it "is false when unsubscribed and past end_date (cancelled or failed)" do
      subscription = Subscription.new(state: :unsubscribed, end_date: 1.day.ago)

      expect(subscription.active?).to eq(false)
    end
  end

  describe "#trial?" do
    it "is true for a trial subscription" do
      expect(Subscription.new(state: :unsubscribed).trial?).to eq(true)
    end
  end
end

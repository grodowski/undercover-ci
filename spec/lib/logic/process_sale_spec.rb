# frozen_string_literal: true

require "rails_helper"

describe Logic::ProcessSale do
  let(:gumroad_ping_params) do
    {
      "seller_id" => "xxxx",
      "product_id" => "xxxx",
      "product_name" => "UndercoverCI - Private Repositories",
      "permalink" => "1337",
      "product_permalink" => "https://gum.co/1337",
      "email" => "jan@undercover-ci.com",
      "price" => "53900",
      "currency" => "usd",
      "quantity" => "1",
      "order_number" => "904300283",
      "sale_id" => "13371337",
      "sale_timestamp" => "2020-09-19T14:55:37Z",
      "purchaser_id" => "1",
      "subscription_id" => "1337SUB",
      "url_params" => {
        "source_url" => "http%3A%2F%2Flocalhost%3A3000%2Fsettings",
        "installation_id" => "123123"
      },
      "variants" => {"Tier" => "Organisation"},
      "test" => "true",
      "license_key" => "1337",
      "ip_country" => "Poland",
      "recurrence" => "yearly",
      "is_gift_receiver_purchase" => "false",
      "refunded" => "false",
      "resource_name" => "sale",
      "disputed" => "false",
      "dispute_won" => "false"
    }
  end

  let(:gumroad_sale) { DataObjects::Gumroad::Sale.new(gumroad_ping_params) }
  subject { described_class.new(gumroad_sale) }

  it "returns an error when a subscription with license key already exists" do
    installation = Installation.create!(installation_id: "123123")
    Subscription.create!(
      state: :unsubscribed,
      installation: installation,
      gumroad_id: "subxxx",
      license_key: "1337"
    )
    expect(Raven)
      .to receive(:capture_exception)
      .with("1337SUB error: license key already used")
      .once

    res = nil
    expect { res = subject.call }.not_to change(Subscription, :count)
    expect(res.error?).to eq(true)
    expect(res.error).to eq("license key already used")
  end

  it "associates an Installation with a new license key" do
    installation = Installation.create!(installation_id: "123123")

    allow_any_instance_of(Gumroad::ValidateLicense)
      .to receive(:call) { Logic::Status.new(nil) }

    res = nil
    expect { res = subject.call }.to change(Subscription, :count).by(1)
    expect(res.error?).to eq(false)

    subscription = installation.subscription
    expect(subscription).to be_persisted
    expect(subscription.attributes).to match(
      hash_including(
        "gumroad_id" => "1337SUB",
        "license_key" => "1337",
        "state" => "subscribed",
        "end_date" => nil
      )
    )
  end

  it "fails if a license key is invalid" do
    installation = Installation.create!(installation_id: "123123")

    allow_any_instance_of(Gumroad::ValidateLicense)
      .to receive(:call) { Logic::Status.new("inactive license key") }

    res = nil
    expect { res = subject.call }.not_to change(Subscription, :count)
    expect(res.error?).to eq(true)
    expect(res.error).to eq("gumroad license error, inactive license key")

    expect(installation.subscription).to be_nil
  end

  it "fails if Gumroad doesn't deliver the installation_id" do
    gumroad_ping_params["url_params"].delete("installation_id")

    expect { subject.call }.to raise_error(KeyError)
  end
end

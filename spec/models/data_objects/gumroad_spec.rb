# frozen_string_literal: true

require "rails_helper"

describe DataObjects::Gumroad do
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
        "installation_id" => "11589779"
      },
      "variants" => {"Tier" => "Organisation"},
      "test" => "true",
      "license_key" => "F9A0081A-5E5248D9-AF212F19-A9BCEF93",
      "ip_country" => "Poland",
      "recurrence" => "yearly",
      "is_gift_receiver_purchase" => "false",
      "refunded" => "false",
      "resource_name" => "sale",
      "disputed" => "false",
      "dispute_won" => "false"
    }
  end

  subject { DataObjects::Gumroad::Sale.new(gumroad_ping_params) }

  it "has a license_key" do
    expect(subject.license_key).to eq("F9A0081A-5E5248D9-AF212F19-A9BCEF93")
  end

  it "has an installation_id" do
    expect(subject.installation_id).to eq("11589779")
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Gumroad::ValidateLicense do
  subject { described_class.new("XXX_LICENSE_XXX").call }

  it "returns success if subscription is active" do
    stub_const("Gumroad::SUBSCRIPTION_PRODUCT_PERMALINK", "xxxx")
    stub_license_verify(success_response)

    expect(subject).to be_success
  end

  it "returns failure if subscription was cancelled" do
    stub_license_verify(
      success_response.merge("subscription_cancelled_at" => "2020-09-19T12:55:06Z")
    )

    expect(subject).to be_error
    expect(subject.error).to eq("inactive license key")
  end

  it "returns failure if license does not exist" do
    stub_license_verify(
      {
        "success" => false,
        "message" => "That license does not exist for the provided product."
      },
      status: 404
    )

    expect(subject).to be_error
    expect(subject.error).to eq("That license does not exist for the provided product.")
  end

  it "raises a RequestError with an unknown error" do
    stub_license_verify({"success" => false}, status: 503)

    expect { subject }.to raise_error(Gumroad::RequestError, "503 {\"success\":false}")
  end

  let(:success_response) do
    {
      "success" => true,
      "uses" => 3,
      "purchase" => {
        "seller_id" => "xxxx",
        "product_id" => "xxxx",
        "product_name" => "UndercoverCI - Private Repositories",
        "permalink" => "xxxx",
        "product_permalink" => "https://gum.co/xxxx",
        "email" => "jan@undercover-ci.com",
        "price" => 4900,
        "currency" => "usd",
        "quantity" => 1,
        "order_number" => 123,
        "sale_id" => "xxxx",
        "sale_timestamp" => "2020-09-19T12:55:06Z",
        "purchaser_id" => "xxxx",
        "subscription_id" => "xxxx",
        "variants" => "(Organisation)",
        "test" => true,
        "license_key" => "xxxxkey",
        "ip_country" => "Germany",
        "recurrence" => "yearly",
        "is_gift_receiver_purchase" => false,
        "refunded" => false,
        "disputed" => false,
        "dispute_won" => false,
        "id" => "xxxx",
        "created_at" => "2020-09-19T12:55:06Z",
        "custom_fields" => [],
        "subscription_cancelled_at" => nil,
        "subscription_failed_at" => nil
      }
    }
  end

  def stub_license_verify(payload, status: 200)
    WebMock
      .stub_request(:post, "https://api.gumroad.com/v2/licenses/verify")
      .to_return(
        status: status,
        body: payload.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end
end

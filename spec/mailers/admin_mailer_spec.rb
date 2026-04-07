# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminMailer, type: :mailer do
  let(:user) { User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo") }
  let(:installation) do
    Installation.create!(
      installation_id: "99999",
      users: [user],
      metadata: {target_type: "Organization", account: {login: "acme-corp"}}
    )
  end

  before { stub_const("ENV", ENV.to_h.merge("ADMIN_EMAIL" => "admin@example.com")) }

  describe "#new_installation" do
    subject(:mail) { described_class.new_installation(installation) }

    it "sends to ADMIN_EMAIL" do
      expect(mail.to).to eq(["admin@example.com"])
    end

    it "has correct subject" do
      expect(mail.subject).to eq("New installation: 99999")
    end

    it "includes the installation id in the body" do
      expect(mail.body.encoded).to include("99999")
    end

    it "includes the installation type in the body" do
      expect(mail.body.encoded).to include("organization")
    end
  end
end

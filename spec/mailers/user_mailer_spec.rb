# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  let(:user) { User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo") }

  let(:repo_stats_with_failures) do
    {
      "acme/backend" => {
        passed: 5,
        failed: 2,
        hotspots: {
          ["app/workers/foo_worker.rb", "perform"] => 12,
          ["app/services/bar_service.rb", "call"] => 8
        }
      },
      "acme/frontend" => {passed: 3, failed: 0, hotspots: {}}
    }
  end

  let(:repo_stats_single_failure) do
    {
      "acme/backend" => {passed: 5, failed: 1, hotspots: {}},
      "acme/frontend" => {passed: 3, failed: 0, hotspots: {}}
    }
  end

  let(:repo_stats_all_passed) do
    {
      "acme/backend" => {passed: 5, failed: 0, hotspots: {}},
      "acme/frontend" => {passed: 3, failed: 0, hotspots: {}}
    }
  end

  describe "#weekly_summary" do
    context "when all checks passed" do
      subject(:mail) { described_class.weekly_summary(user, repo_stats_all_passed) }

      it "sends to the user's email" do
        expect(mail.to).to eq(["foo@bar.com"])
      end

      it "has a subject saying all checks passed" do
        expect(mail.subject).to eq("UndercoverCI: all checks passed this week")
      end

      it "includes repo names in the body" do
        expect(mail.body.encoded).to include("acme/backend")
        expect(mail.body.encoded).to include("acme/frontend")
      end

      it "includes link to settings in the body" do
        expect(mail.body.encoded).to include("settings")
      end
    end

    context "when some checks failed" do
      subject(:mail) { described_class.weekly_summary(user, repo_stats_with_failures) }

      it "sends to the user's email" do
        expect(mail.to).to eq(["foo@bar.com"])
      end

      it "has a subject naming the top repo and warning count" do
        expect(mail.subject).to eq("UndercoverCI: acme/backend — 2 checks had warnings this week")
      end

      it "includes repo names in the body" do
        expect(mail.body.encoded).to include("acme/backend")
        expect(mail.body.encoded).to include("acme/frontend")
      end
    end

    context "when a single check failed" do
      subject(:mail) { described_class.weekly_summary(user, repo_stats_single_failure) }

      it "uses the singular 'check' in the subject" do
        expect(mail.subject).to eq("UndercoverCI: acme/backend — 1 check had warnings this week")
      end
    end
  end
end

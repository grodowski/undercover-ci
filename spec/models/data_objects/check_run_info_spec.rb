# frozen_string_literal: true

require "rails_helper"

describe DataObjects::CheckRunInfo do
  describe "guesses the base_sha from the payload" do
    it "prefers the first pull request base available" do
      payload = OpenStruct.new(
        "action" => "requested",
        "check_suite" => {
          "head_sha" => "head_commit",
          "head_branch" => "feature_branch",
          "before" => "before_commit",
          "pull_requests" => [
            {"base" => {"ref" => "master", "sha" => "pr_base_commit"}}
          ]
        },
        "repository" => {
          "default_branch" => "master"
        }
      )

      expect(described_class.find_base_sha(payload)).to eq("pr_base_commit")
    end

    it "falls back to repository base branch" do
      payload = OpenStruct.new(
        "action" => "requested",
        "check_suite" => {
          "head_sha" => "head_commit",
          "head_branch" => "feature_branch",
          "before" => "before_commit",
          "pull_requests" => []
        },
        "repository" => {
          "default_branch" => "master"
        }
      )

      expect(described_class.find_base_sha(payload)).to eq("master")
    end

    it "uses previous commit if head_sha is on repository default branch" do
      payload = OpenStruct.new(
        "action" => "requested",
        "check_suite" => {
          "head_sha" => "head_commit",
          "head_branch" => "master",
          "before" => "before_commit",
          "pull_requests" => []
        },
        "repository" => {
          "default_branch" => "master"
        }
      )

      expect(described_class.find_base_sha(payload)).to eq("HEAD~1")
    end
  end

  describe "#critical?" do
    let(:run) { described_class.new }

    it "is false without critical paths" do
      expect(run.critical?("app/models/billing/invoice.rb")).to be false
    end

    it "matches paths relative to the repository root" do
      run.critical_paths = ["app/models/billing/**/*", "lib/{auth,payments}/*.rb"]

      expect(run.critical?("app/models/billing/invoice.rb")).to be true
      expect(run.critical?("app/models/billing/stripe/charge.rb")).to be true
      expect(run.critical?("lib/auth/token.rb")).to be true
      expect(run.critical?("lib/payments/card.rb")).to be true
      expect(run.critical?("lib/payments/stripe/card.rb")).to be false
      expect(run.critical?("lib/mailers/receipt.rb")).to be false
      expect(run.critical?("apps/dash/app/models/billing/invoice.rb")).to be false
    end
  end
end

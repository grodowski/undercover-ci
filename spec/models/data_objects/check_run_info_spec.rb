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
            {"base" => {"ref" => "pr_base_commit"}}
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

      expect(described_class.find_base_sha(payload)).to eq("before_commit")
    end
  end
end

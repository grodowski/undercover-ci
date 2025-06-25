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

  describe "#branch_matches_filter?" do
    let(:installation) do
      Installation.create!(
        installation_id: "123123",
        users: [user],
        metadata: {target_type: "User"}
      )
    end

    context "when no filter is set" do
      it "returns true for any branch" do
        expect(installation.branch_matches_filter?("main")).to be true
        expect(installation.branch_matches_filter?("feature/test")).to be true
        expect(installation.branch_matches_filter?("develop")).to be true
      end
    end

    context "when per-repo filter is set" do
      before do
        installation.update!(
          settings: {
            repo_branch_filters: {
              "owner/repo1" => "^(main|develop)$",
              "owner/repo2" => "^main$"
            }
          }
        )
      end

      it "uses per-repo filter when repo is specified" do
        expect(installation.branch_matches_filter?("main", "owner/repo1")).to be true
        expect(installation.branch_matches_filter?("develop", "owner/repo1")).to be true
        expect(installation.branch_matches_filter?("feature/test", "owner/repo1")).to be false
      end

      it "uses different per-repo filter for different repos" do
        expect(installation.branch_matches_filter?("main", "owner/repo2")).to be true
        expect(installation.branch_matches_filter?("develop", "owner/repo2")).to be false
      end

      it "allows all branches for repos without specific filter" do
        expect(installation.branch_matches_filter?("main", "owner/repo3")).to be true
        expect(installation.branch_matches_filter?("develop", "owner/repo3")).to be true
        expect(installation.branch_matches_filter?("feature/test", "owner/repo3")).to be true
      end

      it "allows all branches when no repo is specified" do
        expect(installation.branch_matches_filter?("main")).to be true
        expect(installation.branch_matches_filter?("develop")).to be true
        expect(installation.branch_matches_filter?("feature/test")).to be true
      end
    end

    context "when per-repo filter regex is invalid" do
      before do
        installation.update!(
          settings: {
            repo_branch_filters: {
              "owner/repo1" => "["
            }
          }
        )
      end

      it "returns true (falls back to allowing all branches)" do
        expect(installation.branch_matches_filter?("main", "owner/repo1")).to be true
        expect(installation.branch_matches_filter?("feature/test", "owner/repo1")).to be true
      end
    end
  end

  describe "#set_repo_branch_filter" do
    let(:installation) do
      Installation.create!(
        installation_id: "123123",
        users: [user],
        metadata: {target_type: "User"}
      )
    end

    it "sets a filter for a specific repo" do
      installation.set_repo_branch_filter("owner/repo1", "^main$")
      expect(installation.repo_branch_filters["owner/repo1"]).to eq("^main$")
    end

    it "removes a filter when blank value is provided" do
      installation.set_repo_branch_filter("owner/repo1", "^main$")
      installation.set_repo_branch_filter("owner/repo1", "")
      expect(installation.repo_branch_filters["owner/repo1"]).to be_nil
    end

    it "strips whitespace from filter" do
      installation.set_repo_branch_filter("owner/repo1", "  ^main$  ")
      expect(installation.repo_branch_filters["owner/repo1"]).to eq("^main$")
    end
  end
end

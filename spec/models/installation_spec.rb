# frozen_string_literal: true

require "rails_helper"

RSpec.describe Installation, type: :model do
  let(:user) { User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo") }

  describe "create" do
    before { stub_const("ENV", ENV.to_h.merge("ADMIN_EMAIL" => "admin@example.com")) }

    it "enqueues an admin notification email" do
      expect do
        Installation.create!(
          installation_id: "123123", users: [user],
          metadata: {target_type: "Organization"}
        )
      end.to have_enqueued_mail(AdminMailer, :new_installation)
    end

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

  describe "#set_repo_critical_paths" do
    let(:installation) do
      Installation.create!(
        installation_id: "123123",
        users: [user],
        metadata: {target_type: "User"}
      )
    end

    it "parses one glob per line, dropping blanks, comments and duplicates" do
      text = "  app/models/billing/**/*  \r\n\n# payments\nlib/payments/**/*.rb\napp/models/billing/**/*\n"

      installation.set_repo_critical_paths("owner/repo1", text)

      expect(installation.repo_critical_paths["owner/repo1"]).to eq(["app/models/billing/**/*", "lib/payments/**/*.rb"])
    end

    it "drops comments after a pattern" do
      text = "app/models/billing/**/*  # billing code\n**/*.rb\t# all Ruby\n"

      installation.set_repo_critical_paths("owner/repo1", text)

      expect(installation.repo_critical_paths["owner/repo1"]).to eq(["app/models/billing/**/*", "**/*.rb"])
    end

    it "removes the repo when no globs are left" do
      installation.set_repo_critical_paths("owner/repo1", "lib/**/*")
      installation.set_repo_critical_paths("owner/repo1", "# nothing\n")

      expect(installation.repo_critical_paths).not_to have_key("owner/repo1")
    end

    it "rejects too many or too long patterns" do
      max_globs = Array.new(Installation::MAX_CRITICAL_PATHS) { "lib/#{it}.rb" }
      installation.set_repo_critical_paths("owner/repo1", max_globs.join("\n"))
      installation.set_repo_critical_paths("owner/repo2", "a" * Installation::MAX_CRITICAL_PATH_LENGTH)
      expect(installation).to be_valid

      installation.set_repo_critical_paths("owner/repo1", (max_globs + ["lib/x.rb"]).join("\n"))
      expect(installation).not_to be_valid
      expect(installation.errors.full_messages).to eq(
        ["Critical paths are limited to 50 patterns of up to 200 characters"]
      )

      installation.set_repo_critical_paths("owner/repo1", "")
      installation.set_repo_critical_paths("owner/repo2", "a" * (Installation::MAX_CRITICAL_PATH_LENGTH + 1))
      expect(installation).not_to be_valid
    end
  end
end

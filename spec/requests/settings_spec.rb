# frozen_string_literal: true

require "rails_helper"

describe "Settings" do
  let!(:user) do
    User.create!(
      uid: "1337",
      token: "t0k3n",
      email: "foo@undercover-ci.com",
      name: "foo"
    )
  end

  let!(:installation) do
    Installation.create!(
      installation_id: "1337",
      settings: {}
    ).tap { |inst| inst.users << user }
  end

  let(:github_installations) { [{id: "1337", target_type: "User"}] }
  before do
    stub_request(:get, "https://api.github.com/user/installations/1337/repositories?per_page=100")
      .to_return(
        status: 200,
        body: {
          repositories: [
            {id: 1, full_name: "grodowski/undercover", private: false, url: "https://api.github.com/repos/grodowski/undercover"}
          ]
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )
    stub_request(:get, "https://api.github.com/user/installations?per_page=100")
      .to_return(
        status: 200,
        body: "{\"total_count\": 0, \"installations\": #{github_installations.to_json}}",
        headers: {"Content-Type" => "application/json"}
      )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  end

  describe "PATCH /settings" do
    before do
      get("/auth/github/callback")
    end

    it "updates branch filter for repository" do
      patch(
        "/settings", params: {
          installation_id: "1337",
          repo_full_name: "owner/repo",
          branch_filter_regex: "main|develop"
        }
      )

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("Saved settings for owner/repo")
      expect(installation.reload.settings["repo_branch_filters"]["owner/repo"]).to eq("main|develop")
    end

    it "updates failure_mode for repository" do
      patch(
        "/settings", params: {
          installation_id: "1337",
          repo_full_name: "owner/repo",
          failure_mode: "neutral"
        }
      )

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("Saved settings for owner/repo")
      expect(installation.reload.settings["repo_failure_modes"]["owner/repo"]).to eq("neutral")
    end

    it "fails with unsupported failure mode" do
      patch(
        "/settings", params: {
          installation_id: "1337",
          repo_full_name: "owner/repo",
          failure_mode: "b4c0n"
        }
      )

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("Invalid failure mode")
    end

    it "removes branch filter when blank" do
      installation.set_repo_branch_filter("owner/repo", "existing-filter")
      installation.save!

      patch(
        "/settings", params: {
          installation_id: "1337",
          repo_full_name: "owner/repo",
          branch_filter_regex: ""
        }
      )

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("Saved settings for owner/repo")
      expect(installation.reload.settings["repo_branch_filters"]).not_to have_key("owner/repo")
    end

    it "updates critical paths for repository" do
      patch(
        "/settings", params: {
          installation_id: "1337",
          repo_full_name: "owner/repo",
          failure_mode: "neutral",
          critical_paths: "app/models/billing/**/*\n# auth\nlib/auth/*.rb\n"
        }
      )

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("Saved settings for owner/repo")
      expect(installation.reload.repo_critical_paths["owner/repo"]).to eq(["app/models/billing/**/*", "lib/auth/*.rb"])
    end

    it "rejects too many critical paths" do
      installation.set_repo_critical_paths("owner/repo", "lib/**/*")
      installation.save!

      patch(
        "/settings", params: {
          installation_id: "1337",
          repo_full_name: "owner/repo",
          failure_mode: "neutral",
          critical_paths: Array.new(51) { "lib/#{it}.rb" }.join("\n")
        }
      )

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("Critical paths are limited to 50 patterns of up to 200 characters")
      installation.reload
      expect(installation.repo_critical_paths["owner/repo"]).to eq(["lib/**/*"])
      expect(installation.repo_failure_modes).not_to have_key("owner/repo")
    end

    it "redirects with alert when repo_full_name is missing" do
      patch(
        "/settings", params: {
          installation_id: "1337",
          branch_filter_regex: "main"
        }
      )

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("Repository name is required")
    end
  end

  it "renders the critical paths field for each repository" do
    installation.set_repo_critical_paths("grodowski/undercover", "app/models/billing/**/*\nlib/auth/*.rb")
    installation.save!
    get("/auth/github/callback")

    get("/settings")

    textarea = Nokogiri::HTML(response.body).at_css("textarea[name=critical_paths]")
    expect(textarea.text.strip).to eq("app/models/billing/**/*\nlib/auth/*.rb")
    expect(textarea["placeholder"]).to eq("app/models/billing/**/*\nlib/payments/**/*.rb")
    expect(response.body).to include("relative to the repository root")
  end

  it "resets user access token" do
    allow(SecureRandom).to receive(:hex) { String.new("s3krit") }
    get("/auth/github/callback")
    post("/settings/access_token")

    expect(response).to redirect_to(settings_path)

    get("/settings")
    body = response.body
    expect(body).to include("Ensure your user API token is stored securely.")
    expect(body).to include(
      "<input type=\"text\" class=\"form-control\" readonly " \
      "placeholder=\"No access token generated\" value=\"s3krit\"/>"
    )

    get("/v1/checks/notexists.json")
    expect(response.status).to eq(401)

    get("/v1/checks/notexists.json", headers: {HTTP_AUTHORIZATION: "Token token=s3krit"})
    expect(response.status).to eq(404)
  end
end

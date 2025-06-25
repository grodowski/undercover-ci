# frozen_string_literal: true

require "rails_helper"

describe "Dashboard spec" do
  let!(:user) do
    User.create!(
      uid: "1337",
      token: "t0k3n",
      email: "foo@undercover-ci.com",
      name: "foo"
    )
  end

  let(:github_installations) { [{id: "1337"}] }
  before do
    stub_request(:get, "https://api.github.com/user/installations/1337/repositories?per_page=100")
      .to_return(
        status: 200,
        body: {
          repositories: [{id: 1, url: "https://api.github.com/repos/grodowski/undercover"}]
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

  describe "GET /app" do
    context "without any installations" do
      let(:github_installations) { [] }

      it "renders dashboard#index for a signed in user" do
        get("/auth/github/callback")

        get("/app")
        expect(response).to redirect_to("/settings/new")
      end

      it "removes outstanding UserInstallations for current user" do
        inst = Installation.create!(installation_id: 1337, users: [user])

        expect do
          get("/auth/github/callback")
          get("/app")
        end.to change { inst.reload.users }.from([user]).to([])

        expect(inst).to be_persisted
      end
    end

    it "redirects to root url for an anonymous user" do
      expect(get("/app")).to redirect_to root_url
    end

    it "renders checks/index when setup is complete" do
      inst = Installation.create!(installation_id: 1337, users: [user])
      check = CoverageCheck.create!(head_sha: "1337SHA", installation: inst)
      check.nodes.create(
        path: "foo.rb",
        node_name: "hello",
        node_type: "instance method",
        start_line: 1,
        end_line: 3,
        coverage: 0.6,
        flagged: true
      )
      passed_check = CoverageCheck.create!(head_sha: "2337SHA", installation: inst)
      passed_check.nodes.create(
        path: "foo.rb",
        node_name: "hello",
        node_type: "instance method",
        start_line: 1,
        end_line: 3,
        coverage: 1.0,
        flagged: false
      )

      get("/auth/github/callback")
      get("/app")
      expect(response.body).to include(
        "<a href=\"https://github.com//commit/1337SHA\"><code>1337SHA</code> 👉 <code></code></a>"
      )
      expect(response.body).to include("<span class=\"badge rounded-pill text-bg-warning\">1 warning</span>")
      expect(response.body).to include("<span class=\"badge rounded-pill text-bg-success\">0 warnings</span>")
    end

    context "filter_checks_from_params functionality" do
      let!(:inst) { Installation.create!(installation_id: 1337, users: [user]) }
      let!(:old_check) do
        CoverageCheck.create!(
          head_sha: "OLD_SHA", installation: inst, created_at: 2.months.ago,
          repo: {"full_name" => "owner/repo1"}, check_suite: {"head_branch" => "main"}, result: "failed"
        )
      end
      let!(:recent_check) do
        CoverageCheck.create!(
          head_sha: "RECENT_SHA", installation: inst, created_at: 1.day.ago,
          repo: {"full_name" => "owner/repo2"}, check_suite: {"head_branch" => "feature"}, result: "passed"
        )
      end

      before do
        get("/auth/github/callback")
      end

      it "filters by date range" do
        get("/app", params: {date_range: "last_7d"})
        expect(response.body).to include("RECENT_S")
        expect(response.body).not_to include("OLD_SHA")
      end

      it "filters by repository name" do
        get("/app", params: {repository_name: "owner/repo1", date_range: "last_90d"})
        expect(response.body).to include("OLD_SHA")
        expect(response.body).not_to include("RECENT_S")
      end

      it "filters by branch name" do
        get("/app", params: {branch_name: "feature"})
        expect(response.body).to include("RECENT_S")
        expect(response.body).not_to include("OLD_SHA")
      end

      it "filters by result status" do
        get("/app", params: {result: "passed"})
        expect(response.body).to include("RECENT_S")
        expect(response.body).not_to include("OLD_SHA")
      end

      it "handles 'all' values for filters" do
        get("/app", params: {repository_name: "all", branch_name: "all", result: "all", date_range: "last_90d"})
        expect(response.body).to include("OLD_SHA")
        expect(response.body).to include("RECENT_S")
      end

      it "combines multiple filters" do
        get("/app", params: {date_range: "last_7d", result: "passed"})
        expect(response.body).to include("RECENT_S")
        expect(response.body).not_to include("OLD_SHA")
      end
    end

    context "with a github installation" do
      let(:github_installations) { [{id: 1_337, app_id: 18_310}] }

      it "creates a user_installation and installation" do
        get("/auth/github/callback")
        get("/app")

        expect(Installation.count).to eq(1)
        expect(Installation.last.users).to contain_exactly(user)
      end

      it "refreshes the installation if it already exists" do
        other_user = User.create!(uid: "1337-guest", token: "t0k3n", email: "foo@e.com", name: "foo")
        inst = Installation.create!(installation_id: 1_337, users: [other_user])

        get("/auth/github/callback")
        get("/app")

        expect(Installation.count).to eq(1)

        inst.reload
        user.reload

        expect(inst.repos).to contain_exactly(
          "id" => 1, "url" => "https://api.github.com/repos/grodowski/undercover"
        )
        expect(user.installations).to contain_exactly(inst)
        expect(inst.users).to contain_exactly(user, other_user)
      end
    end
  end

  describe "GET /checks/:id" do
    it "renders checks/show" do
      inst = Installation.create!(installation_id: 1337, users: [user])
      check = CoverageCheck.create!(head_sha: "1337SHA", installation: inst)
      [[1.0, false], [0.8, false], [0.6, true]].each do |coverage, flagged|
        check.nodes.create!(
          path: "foo.rb",
          node_name: "hello",
          node_type: "instance method",
          start_line: 1,
          end_line: 3,
          coverage:,
          flagged:
        )
      end

      get("/auth/github/callback")
      get("/checks/#{check.id}")
      expect(response.body).to include("<span class=\"badge rounded-pill text-bg-warning\">warning</span>")
      expect(response.body).to include(
        "Instance method <code>hello</code>. " \
        "Coverage: <span class=\"node-coverage-yellow\">60.0%</span><span> (contains untested " \
        "diff lines)</span>"
      )
      expect(response.body).to include(
        "Instance method <code>hello</code>. " \
        "Coverage: <span class=\"node-coverage-default\">100.0%</span><span></span>"
      )
      expect(response.body).to include(
        "Instance method <code>hello</code>. " \
        "Coverage: <span class=\"node-coverage-blue\">80.0%</span><span></span>"
      )
    end
  end
end

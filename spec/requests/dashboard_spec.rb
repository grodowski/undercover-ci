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

      get("/auth/github/callback")
      get("/app")
      expect(response.body).to include(
        "<a href=\"https://github.com//commit/1337SHA\"><code>1337SHA</code> 👉 <code></code></a>"
      )
      expect(response.body).to include("<span class=\"badge badge-warning\">1 warning</span>")
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
      expect(response.body).to include("<span class=\"badge badge-warning\">warning</span>")
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

# frozen_string_literal: true

require "rails_helper"

describe "Dashboard spec" do
  let(:user) do
    User.create!(
      uid: "1337",
      token: "t0k3n",
      email: "foo@undercover-ci.com",
      name: "foo"
    )
  end

  before do
    stub_request(:get, "https://api.github.com/user/installations?per_page=100")
      .to_return(
        status: 200,
        body: "{\"total_count\": 0, \"installations\": []}",
        headers: {"Content-Type" => "application/json"}
      )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  end

  describe "GET /app" do
    it "renders dashboard#index for a signed in user" do
      get("/auth/github/callback")

      get("/app")
      expect(response).to redirect_to("/settings/new")
    end

    it "redirects to root url for an anonymous user" do
      expect(get("/app")).to redirect_to root_url
    end

    it "renders checks/index when setup is complete" do
      inst = Installation.create!(installation_id: 43_009_808, user: user)
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
      expect(get("/app")).to render_template("dashboard/checks/index")
      expect(response.body).to include(
        "<a href=\"https://github.com//commit/1337SHA\"><code>1337SHA</code> 👉 <code></code></a>"
      )
      expect(response.body).to include("<span class=\"badge badge-warning\">1 warning</span>")
    end
  end

  describe "GET /checks/:id" do
    it "renders checks/show" do
      inst = Installation.create!(installation_id: 43_009_808, user: user)
      check = CoverageCheck.create!(head_sha: "1337SHA", installation: inst)
      [[1.0, false], [0.8, false], [0.6, true]].each do |coverage, flagged|
        check.nodes.create!(
          path: "foo.rb",
          node_name: "hello",
          node_type: "instance method",
          start_line: 1,
          end_line: 3,
          coverage: coverage,
          flagged: flagged
        )
      end

      get("/auth/github/callback")
      expect(get("/checks/#{check.id}")).to render_template("dashboard/checks/show")
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

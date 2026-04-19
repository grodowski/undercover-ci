# frozen_string_literal: true

require "rails_helper"

describe "/blog" do
  describe "GET /blog/:slug" do
    it "renders a known post" do
      get "/blog/claude-code-experiment"
      expect(response.status).to eq(200)
      expect(response.body).to include("Teaching Claude Code to Test What Breaks")
    end

    it "returns 404 for unknown slug" do
      get "/blog/does-not-exist"
      expect(response.status).to eq(404)
    end
  end
end

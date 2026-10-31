# frozen_string_literal: true

require "rails_helper"

describe ApplicationHelper do
  let(:installation) do
    user = User.create!(uid: "1337", email: "foo@bar.com", token: "sekritkey", name: "Foo Bar")
    Installation.create!(installation_id: "123123", users: [user])
  end
  let(:coverage_check) do
    CoverageCheck.create!(
      installation:,
      head_sha: "b4c0n1b4c0n1",
      repo: {"full_name" => "author/repo", "default_branch" => "main"},
      state: :awaiting_coverage
    )
  end

  describe "#pull_request_or_commit_link" do
    it "links to the pull request of a check created from a fork upload" do
      coverage_check.update!(pull_request_number: 42)

      link = helper.pull_request_or_commit_link(coverage_check)

      expect(link).to include("https://github.com/author/repo/pull/42/checks")
      expect(link).to include("#42 @ b4c0n1b4")
    end

    it "shows the full target branch of a check created from a fork upload" do
      coverage_check.update!(pull_request_number: 42, base_sha: "release/2.0")

      expect(helper.pull_request_or_commit_link(coverage_check)).to include("<code>release/2.0</code>")
    end

    it "shortens a base commit sha" do
      coverage_check.update!(base_sha: "953a8049abaaa57f8db4ff97a55114283355d17e")

      expect(helper.pull_request_or_commit_link(coverage_check)).to include("<code>953a8049</code>")
    end

    it "falls back to the default branch without a base" do
      expect(helper.pull_request_or_commit_link(coverage_check)).to include("<code>main</code>")
    end

    it "links to the commit when there is no pull request" do
      expect(helper.pull_request_or_commit_link(coverage_check))
        .to include("https://github.com/author/repo/commit/b4c0n1b4c0n1")
    end

    it "links to the pull request from a check_suite payload" do
      coverage_check.update!(
        check_suite: {
          "pull_requests" => [
            {"number" => 7, "head" => {"ref" => "feature"}, "base" => {"ref" => "main"}}
          ]
        }
      )

      link = helper.pull_request_or_commit_link(coverage_check)

      expect(link).to include("https://github.com/author/repo/pull/7/checks")
      expect(link).to include("#7 @ b4c0n1b4")
      expect(link).to include("main")
      expect(link).not_to include("feature")
    end
  end
end

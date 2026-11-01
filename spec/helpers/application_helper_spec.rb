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
      repo: {"id" => 1, "full_name" => "author/repo", "default_branch" => "main"},
      state: :awaiting_coverage
    )
  end

  def pull_request(number, base_ref, repo_id: 1)
    {"number" => number, "base" => {"ref" => base_ref, "repo" => {"id" => repo_id}}}
  end

  describe "#pull_request_label" do
    it "uses the number of a check created from a fork upload" do
      coverage_check.update!(pull_request_number: 42)

      expect(helper.pull_request_label(coverage_check)).to eq("#42")
    end

    it "uses the number from a check_suite payload" do
      coverage_check.update!(check_suite: {"pull_requests" => [pull_request(7, "main")]})

      expect(helper.pull_request_label(coverage_check)).to eq("#7")
    end

    it "ignores an upstream pull request listed on a fork's check" do
      coverage_check.update!(check_suite: {"pull_requests" => [pull_request(62, "main", repo_id: 2)]})

      expect(helper.pull_request_label(coverage_check)).to be_nil
      expect(helper.github_link(coverage_check)).to include("/commit/b4c0n1b4c0n1")
    end

    it "is empty without a pull request" do
      coverage_check.update!(check_suite: {"pull_requests" => []})

      expect(helper.pull_request_label(coverage_check)).to be_nil
    end
  end

  describe "#github_link" do
    it "links to the pull request checks" do
      coverage_check.update!(pull_request_number: 42)

      expect(helper.github_link(coverage_check))
        .to eq("<a href=\"https://github.com/author/repo/pull/42/checks\">View on GitHub</a>")
    end

    it "links to the commit without a pull request" do
      expect(helper.github_link(coverage_check))
        .to eq("<a href=\"https://github.com/author/repo/commit/b4c0n1b4c0n1\">View on GitHub</a>")
    end
  end

  describe "#compare_base" do
    it "uses the pull request target branch from a check_suite payload" do
      coverage_check.update!(check_suite: {"pull_requests" => [pull_request(7, "develop")]})

      expect(helper.compare_base(coverage_check)).to eq("develop")
    end

    it "shows the full target branch of a check created from a fork upload" do
      coverage_check.update!(pull_request_number: 42, base_sha: "release/2.0")

      expect(helper.compare_base(coverage_check)).to eq("release/2.0")
    end

    it "shortens a base commit sha" do
      coverage_check.update!(base_sha: "953a8049abaaa57f8db4ff97a55114283355d17e")

      expect(helper.compare_base(coverage_check)).to eq("953a8049")
    end

    it "falls back to the default branch without a base" do
      expect(helper.compare_base(coverage_check)).to eq("main")
    end
  end
end

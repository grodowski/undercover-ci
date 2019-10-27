# frozen_string_literal: true

require "rails_helper"

describe CreateCheckRunJob do
  it "posts a GitHub request with coverage check data" do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", user: user)
    check = CoverageCheck.create!(
      installation: installation,
      head_sha: "953a804",
      repo: {"full_name" => "author/repo", "default_branch" => "master"}
    )

    expect(CheckRuns::Create).to receive(:new) do |check_run|
      expect(check_run.sha).to eq(check.head_sha)
      expect(check_run.full_name).to eq(check.repo_full_name)
    end.and_return(instance_double(CheckRuns::Create, post: true))

    described_class.perform_now(check.id)
  end
end

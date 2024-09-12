# frozen_string_literal: true

require "rails_helper"

describe RunnerJob do
  let(:user) do
    User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
  end
  let(:installation) do
    Installation.create!(installation_id: "123123", users: [user])
  end
  let(:check) do
    CoverageCheck.create!(
      installation:,
      repo: {id: 1, full_name: "user/repository"},
      head_sha: "1a2b3c",
      state: :awaiting_coverage
    )
  end

  it "calls Logic::RunUndercover" do
    expect(Logic::RunUndercover).to receive(:call).once.with(check)

    described_class.perform_now(check.id)
  end

  it "throttles when checks are in progress" do

  end
end

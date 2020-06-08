# frozen_string_literal: true

require "rails_helper"

describe RunnerJob do
  let(:check) do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: "sekritkey",
      name: "Foo Bar"
    )
    installation = Installation.create!(installation_id: "123123", users: [user])
    CoverageCheck.create!(
      installation: installation,
      repo: {id: 1, full_name: "user/repository"},
      head_sha: "1a2b3c",
      state: :awaiting_coverage
    )
  end

  it "calls Logic::RunUndercover" do
    expect(Logic::RunUndercover).to receive(:call).once.with(check)

    described_class.perform_now(check.id)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExpireCheckJob, type: :job do
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

  it "expires the check when it's awaiting_coverage" do
    described_class.perform_now(check.id)

    check.reload
    expect(check.state).to eq(:expired)
  end

  it "is a no-op in any other case" do
    check.update!(state: :in_progress)
    described_class.perform_now(check.id)

    check.reload
    expect(check.state).to eq(:in_progress)
  end
end
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
      installation:,
      repo: {id: 1, full_name: "user/repository"},
      head_sha: "1a2b3c",
      state: :awaiting_coverage
    )
  end

  before { allow_any_instance_of(CheckRuns::Canceled).to receive(:post) }

  it "cancels the check when it's awaiting_coverage" do
    expect_any_instance_of(CheckRuns::Canceled).to receive(:post).once

    described_class.perform_now(check.id)

    check.reload
    expect(check.state).to eq(:canceled)
  end

  it "cancels the check when it's in_progress" do
    check.update!(state: :in_progress)
    described_class.perform_now(check.id)

    check.reload
    expect(check.state).to eq(:canceled)
  end

  it "is a no-op when a check is already canceled" do
    check.update!(state: :canceled)

    expect { described_class.perform_now(check.id) }.not_to(change { check.reload.state })
  end
end

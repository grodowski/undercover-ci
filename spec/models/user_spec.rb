# frozen_string_literal: true

require "rails_helper"

describe User, type: :model do
  it "encrypts the GitHub token" do
    sekritkey = "sekritkey" * 20
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      token: sekritkey,
      name: "Foo Bar"
    )

    expect(user[:token]).not_to eq(sekritkey)
    expect(user.token).to eq(sekritkey)

    user.reload
    expect(user.token).to eq(sekritkey)
  end
end

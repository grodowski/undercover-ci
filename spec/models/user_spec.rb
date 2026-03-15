# frozen_string_literal: true

require "rails_helper"

describe User, type: :model do
  before { stub_const("ENV", ENV.to_h.merge("ADMIN_EMAIL" => "admin@example.com")) }

  it "enqueues a delayed admin notification email on create" do
    expect do
      User.create!(uid: "1337", email: "foo@bar.com", token: "tok", name: "Foo Bar")
    end.to have_enqueued_mail(AdminMailer, :new_user).at(a_value_within(5.seconds).of(2.minutes.from_now))
  end

  it "does not enqueue admin notification on update" do
    user = User.create!(uid: "1337", email: "foo@bar.com", token: "tok", name: "Foo Bar")
    expect do
      user.update!(name: "New Name")
    end.not_to have_enqueued_mail(AdminMailer, :new_user)
  end

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

  it "#analytics_id" do
    user = User.create!(
      uid: "1337",
      email: "foo@bar.com",
      name: "Foo Bar",
      token: "tok"
    )

    expect(user.analytics_id).to eq("U#{user.id}")
  end
end

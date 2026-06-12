# frozen_string_literal: true

require "rails_helper"

describe "emails:weekly_summary rake task" do
  include ActiveJob::TestHelper

  let(:task) { Rake::Task["emails:weekly_summary"] }

  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task.reenable
  end

  let(:installation) { Installation.create!(installation_id: "1337", settings: {}) }
  let(:user) do
    User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo").tap do |u|
      installation.users << u
    end
  end

  def create_check(head_sha:, repo: "org/repo", state: "complete", result: "passed")
    CoverageCheck.create!(
      installation:,
      head_sha:,
      repo: {"full_name" => repo, "default_branch" => "main"},
      state:,
      result:
    )
  end

  it "skips users with weekly summary disabled" do
    user.update!(email_preferences: {"weekly_summary_opt_out" => true})
    create_check(head_sha: "abc123")
    expect(UserMailer).not_to receive(:weekly_summary)
    task.invoke
  end

  it "skips users with no recent checks" do
    user
    expect(UserMailer).not_to receive(:weekly_summary)
    task.invoke
  end

  it "sends a weekly summary for users with recent checks" do
    user
    check = create_check(head_sha: "abc123", result: "failed")
    check.nodes.create!(
      path: "app/models/foo.rb",
      node_type: "instance_method",
      node_name: "bar",
      start_line: 1,
      end_line: 5,
      coverage: 0.5,
      flagged: true
    )

    mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    expect(UserMailer).to receive(:weekly_summary).with(
      user,
      hash_including("org/repo" => hash_including(failed: 1, passed: 0))
    ).and_return(mail_double)

    task.invoke
    expect(mail_double).to have_received(:deliver_now)
  end

  it "deduplicates checks by head_sha" do
    user
    create_check(head_sha: "abc123", result: "passed")
    create_check(head_sha: "abc123", result: "passed")

    mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    expect(UserMailer).to receive(:weekly_summary).with(
      user,
      hash_including("org/repo" => hash_including(passed: 1))
    ).and_return(mail_double)

    task.invoke
  end

  it "excludes block nodes from hotspots" do
    user
    check = create_check(head_sha: "abc123", result: "failed")
    check.nodes.create!(
      path: "app/models/foo.rb", node_type: "block", node_name: "block in bar",
      start_line: 1, end_line: 3, coverage: 0.0, flagged: true
    )
    check.nodes.create!(
      path: "app/models/foo.rb", node_type: "instance_method", node_name: "bar",
      start_line: 5, end_line: 10, coverage: 0.0, flagged: true
    )

    mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    expect(UserMailer).to receive(:weekly_summary).with(
      user,
      hash_including(
        "org/repo" => hash_including(
          hotspots: hash_including(["app/models/foo.rb", "bar"] => 1)
        )
      )
    ).and_return(mail_double)

    task.invoke
  end
end

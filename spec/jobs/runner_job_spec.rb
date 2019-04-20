# frozen_string_literal: true

require "rails_helper"

describe RunnerJob do
  let(:check) do
    CoverageCheck.create!(
      repo: {id: 1, full_name: "user/repository"},
      commit_sha: "1a2b3c"
    )
  end

  before do
    @previous_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end
  after { ActiveJob::Base.queue_adapter = @previous_queue_adapter }

  it "retries if coverage_reports are still empty" do
    expect do
      described_class.perform_now(check.id)
    end.to have_enqueued_job(described_class).with(check.id, 2).on_queue("default")
  end

  it "retries 3 times" do
    expect do
      described_class.perform_now(check.id, 3)
    end.to raise_error(Logic::RunUndercover::RunError, "coverage_reports can't be blank")

    expect(described_class).not_to have_been_enqueued
  end
end

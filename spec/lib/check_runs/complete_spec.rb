# frozen_string_literal: true

require "rails_helper"
require "check_runs"

describe CheckRuns::Complete do
  it "transforms Undercover::Result into annotations" do
    run = DataObjects::CheckRunInfo.new(
      "grodowski/undercover-ci",
      "abc123",
      "installation-1",
      nil
    )
    check_run_complete = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_complete).to receive(:installation_api_client) { dummy_github }

    expected_output = hash_including(
      annotations: [
        {
          path: "app/models/application_record.rb",
          start_line: 2,
          end_line: 5,
          annotation_level: "warning",
          title: "Untested instance method",
          message: "Instance method `method` is missing coverage for line 3 (node coverage: 0.5)"
        }
      ]
    )

    check_run_complete.post(
      [undercover_result_fixture]
    )

    expect(dummy_github)
      .to have_received(:post) do |path, payload|
        expect(path).to eq("/repos/grodowski/undercover-ci/check-runs")
        expect(payload[:output]).to match(expected_output)
      end
  end

  def undercover_result_fixture
    mock_node = double(human_name: "instance method", name: "method", first_line: 2, last_line: 5)
    Undercover::Result.new(
      mock_node,
      [[3, 0], [4, 1]],
      "app/models/application_record.rb"
    )
  end
end

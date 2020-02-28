# frozen_string_literal: true

require "rails_helper"
require "check_runs"

describe CheckRuns::Complete do
  describe "#format_lines" do
    it "formats lines" do
      obj = described_class.new(nil)

      expect(obj.format_lines([1])).to eq([1])
      expect(obj.format_lines([1, 2, 3])).to eq([1..3])
      expect(obj.format_lines([1, 3, 4])).to eq([1, 3..4])
      expect(obj.format_lines([1, 2, 4])).to eq([1..2, 4])
      expect(obj.format_lines([1, 2, 4])).to eq([1..2, 4])
      expect(obj.format_lines([1, 2, 4, 6, 2, 1, 2, 3])).to eq([1..2, 4, 6, 2, 1..3])
    end
  end

  it "transforms Undercover::Result into annotations" do
    run = DataObjects::CheckRunInfo.new(
      "grodowski/undercover-ci",
      "abc123",
      "installation-1",
      nil,
      "2020-02-02T16:13:22Z",
      nil,
      :complete,
      1337,
      "2020-02-02T16:20:47Z",
      2
    )
    check_run_complete = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_complete).to receive(:installation_api_client) { dummy_github }

    expected_output = hash_including(
      annotations: [
        {
          path: "app/models/application_record.rb",
          start_line: 1,
          end_line: 5,
          annotation_level: "warning",
          title: "Untested instance method",
          message: "Instance method `method` is missing coverage for lines 3..4 (node coverage: 0.3333)"
        }
      ]
    )

    check_run_complete.post(
      [undercover_result_fixture]
    )

    expect(dummy_github)
      .to have_received(:post) do |path, payload|
        expect(path).to eq("/repos/grodowski/undercover-ci/check-runs")
        expect(payload[:external_id]).to eq(1337)
        expect(payload[:conclusion]).to eq("failure")
        expect(payload[:status]).to eq("completed")
        expect(payload[:completed_at]).to eq("2020-02-02T16:20:47Z")
        expect(payload[:details_url]).to eq("https://undercover-ci.com/checks/1337")
        expect(payload[:output]).to match(expected_output)
      end
  end

  def undercover_result_fixture
    mock_node = double(human_name: "instance method", name: "method", first_line: 1, last_line: 5)
    Undercover::Result.new(
      mock_node,
      [[2, 1], [3, 0], [4, 0]],
      "app/models/application_record.rb"
    )
  end
end

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
      check_run_fixture.nodes
    )
    check_run_complete = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_complete).to receive(:installation_api_client) { dummy_github }

    expected_text = <<~TEXT.chomp
      Revision `abc123` has modified the following 2 code locations. Results marked with ⚠️ have untested lines added or changed in this commit, look into them!

      file | name | coverage
      :--- | :--- | ---:
      app/models/application_record.rb | ⚠️ instance method `method` | 0.0
      app/models/application_record.rb | instance method `method` | 1.0
    TEXT

    expected_output = hash_including(
      summary: "🚨 UndercoverCI has detected 1 warning in this changeset.",
      text: expected_text,
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

    check_run_complete.post(undercover_report_fixture)

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

  def check_run_fixture
    mock_result = undercover_report_fixture.all_results[0]
    # TODO: not ideal, will need refactoring
    inst = Installation.create
    CoverageCheck.create!(
      installation: inst,
      state: :complete,
      nodes: [
        Node.new(
          node_type: "instance method",
          node_name: "method",
          start_line: mock_result.first_line,
          end_line: mock_result.last_line,
          coverage: 1.0,
          flagged: false,
          path: mock_result.file_path
        ),
        Node.new(
          node_type: "instance method",
          node_name: "method",
          start_line: mock_result.first_line,
          end_line: mock_result.last_line,
          coverage: 0.0,
          flagged: true,
          path: mock_result.file_path
        )
      ]
    )
  end

  def undercover_report_fixture
    mock_node = double(human_name: "instance method", name: "method", first_line: 1, last_line: 5)
    results = [
      Undercover::Result.new(
        mock_node,
        [[2, 1], [3, 0], [4, 0]],
        "app/models/application_record.rb"
      ),
      Undercover::Result.new(
        mock_node,
        [[2, 1], [3, 0], [4, 0]],
        "app/models/application_record.rb"
      )
    ]
    instance_double(Undercover::Report, all_results: results, flagged_results: [results[0]])
  end
end

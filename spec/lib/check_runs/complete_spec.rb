# frozen_string_literal: true

require "rails_helper"

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
      Revision `abc123` has modified the following 3 code locations. Results marked with ⚠️ have untested lines added or changed in this commit, look into them!

      file | name | coverage | branches
      :--- | :--- | ---: | ---:
      spec/fixtures/application_record.rb | ⚠️ instance method `method` | 0.0 | 2/4
      spec/fixtures/application_record.rb | ⚠️ instance method `method` | 0.0 | 2/4
      spec/fixtures/application_record.rb | instance method `method` | 1.0 | 2/4
    TEXT

    expected_output = hash_including(
      summary: "🚨 UndercoverCI has detected 2 warnings in this changeset.",
      text: expected_text,
      annotations: [
        {
          path: "spec/fixtures/application_record.rb",
          start_line: 1,
          end_line: 6,
          annotation_level: "warning",
          title: "Untested instance method",
          message: "Instance method `method` is missing coverage for lines 3..5 (node coverage: 0.25)." \
                   "\nMissing branch coverage found in lines 4..5.",
          raw_details: "1: test_line hits: n/a\n" \
                       "2: test_line hits: 1\n" \
                       "3: test_line hits: 0\n" \
                       "4: test_line hits: 0 branches: 1/2\n" \
                       "5: test_line hits: 0 branches: 1/2\n" \
                       "6: test_line hits: n/a"
        },
        {
          path: "spec/fixtures/application_record.rb",
          start_line: 1,
          end_line: 6,
          annotation_level: "warning",
          title: "Untested instance method",
          message: "Instance method `method` is missing coverage for lines 3..5 (node coverage: 0.25)." \
                   "\nMissing branch coverage found in line 4.",
          raw_details: "1: test_line hits: n/a\n" \
                       "2: test_line hits: 1\n" \
                       "3: test_line hits: 0\n" \
                       "4: test_line hits: 0 branches: 1/2\n" \
                       "5: test_line hits: 0 branches: 2/2\n" \
                       "6: test_line hits: n/a"
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

  it "respects failure mode configured by the check run object" do
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
    run.failure_mode = "neutral"
    check_run_complete = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_complete).to receive(:installation_api_client) { dummy_github }

    check_run_complete.post(undercover_report_fixture)

    expect(dummy_github)
      .to have_received(:post) do |path, payload|
        expect(payload[:conclusion]).to eq("neutral")
        expect(path).to eq("/repos/grodowski/undercover-ci/check-runs")
        expect(payload[:external_id]).to eq(1337)
        expect(payload[:status]).to eq("completed")
        expect(payload[:completed_at]).to eq("2020-02-02T16:20:47Z")
        expect(payload[:details_url]).to eq("https://undercover-ci.com/checks/1337")
      end
  end

  it "responds with success conclusion with a successful check run" do
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
      check_run_fixture(result: :passed).nodes
    )
    check_run_complete = described_class.new(run)

    dummy_github = instance_spy(Octokit::Client)
    allow(dummy_github).to receive_message_chain(:last_response, :status)
    allow(check_run_complete).to receive(:installation_api_client) { dummy_github }

    check_run_complete.post(undercover_report_fixture)

    expect(dummy_github)
      .to have_received(:post) do |path, payload|
        expect(payload[:conclusion]).to eq("success")
        expect(path).to eq("/repos/grodowski/undercover-ci/check-runs")
        expect(payload[:external_id]).to eq(1337)
        expect(payload[:status]).to eq("completed")
        expect(payload[:completed_at]).to eq("2020-02-02T16:20:47Z")
        expect(payload[:details_url]).to eq("https://undercover-ci.com/checks/1337")
      end
  end

  it "retries on UnprocessableEntity and enqueues ExpireCheckJob on final failure" do
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
    allow(dummy_github).to receive(:post).and_raise(Octokit::UnprocessableEntity)
    allow_any_instance_of(Octokit::UnprocessableEntity).to receive(:message) { "Only 65535 characters are allowed" }
    allow(check_run_complete).to receive(:installation_api_client) { dummy_github }

    expect(ExpireCheckJob).to receive(:perform_later).with(
      1337,
      "The check output exceeded GitHub's character limit, please inspect " \
      "the UndercoverCI dashboard directly"
    )

    check_run_complete.post(undercover_report_fixture)

    expect(dummy_github).to have_received(:post).exactly(3).times
  end

  def check_run_fixture(result: :failed)
    mock_result = undercover_report_fixture.all_results.first
    mock_result_multi_line_branch_coverage = undercover_report_fixture.all_results[1]
    inst = Installation.create
    CoverageCheck.new(installation: inst, state: :complete).tap do |check|
      if result == :failed
        check.nodes = [
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
          ),
          Node.new(
            node_type: "instance method",
            node_name: "method",
            start_line: mock_result_multi_line_branch_coverage.first_line,
            end_line: mock_result_multi_line_branch_coverage.last_line,
            coverage: 0.0,
            flagged: true,
            path: mock_result_multi_line_branch_coverage.file_path
          )
        ]
        check.save!
      end
    end
  end

  def undercover_report_fixture
    mock_node = double(
      human_name: "instance method", name: "method", first_line: 1, last_line: 6,
      source_lines_with_numbers: (1..6).zip(Array.new(6, "test_line")), empty_def?: false
    )

    mock_adapter_res = instance_double(
      "Undercover::LcovParser",
      coverage: [[2, 1], [3, 0], [4, 0], [5, 0], [4, 0, 1, 1], [4, 0, 2, 0], [5, 0, 1, 1], [5, 0, 2, 0]],
      skipped?: false
    )
    mock_adapter_res2 = instance_double(
      "Undercover::LcovParser",
      coverage: [[2, 1], [3, 0], [4, 0], [5, 0], [4, 0, 1, 1], [4, 0, 2, 0], [5, 0, 1, 1], [5, 0, 2, 1]],
      skipped?: false
    )

    results = [
      Undercover::Result.new(mock_node, mock_adapter_res, "spec/fixtures/application_record.rb"),
      Undercover::Result.new(mock_node, mock_adapter_res2, "spec/fixtures/application_record.rb"),
      Undercover::Result.new(mock_node, mock_adapter_res, "spec/fixtures/application_record.rb")
    ]
    instance_double(Undercover::Report, all_results: results, flagged_results: results[0..1])
  end
end

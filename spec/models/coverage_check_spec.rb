# frozen_string_literal: true

require "rails_helper"

RSpec.describe CoverageCheck, type: :model do
  describe "#installation_active?" do
    let(:coverage_check) { CoverageCheck.new }
    let(:installation) { instance_double(Installation) }

    before do
      allow(coverage_check).to receive(:installation).and_return(installation)
    end

    context "when repo is not public" do
      before do
        allow(coverage_check).to receive(:repo_public?).and_return(false)
      end

      it "delegates the return value to installation.active?" do
        expect(installation).to receive(:active?).and_return(true)
        expect(coverage_check.installation_active?).to be true

        expect(installation).to receive(:active?).and_return(false)
        expect(coverage_check.installation_active?).to be false
      end
    end

    context "when repo is public" do
      it "always returns true" do
        allow(coverage_check).to receive(:repo_public?).and_return(true)
        expect(installation).not_to receive(:active?)
        expect(coverage_check.installation_active?).to be true
      end
    end
  end

  describe "#in_progress_for_installation" do
    let(:user) { User.create!(uid: "1", email: "foo@bar.com", token: "sekrit", name: "Foo") }

    it "returns 0 when there are no in_progress checks" do
      installation = Installation.create!(installation_id: "123123")
      expect(CoverageCheck.in_progress_for_installation(installation)).to be_empty
    end

    it "returns 2 when there are two in_progress checks" do
      installation = Installation.create!(
        installation_id: "123123", users: [user],
        metadata: {target_type: "Organization"}
      )
      CoverageCheck.create!(
        installation:,
        head_sha: "b8f95241",
        repo: {"full_name" => "author/repo", "default_branch" => "master"},
        state: :queued
      )
      CoverageCheck.create!(
        installation:,
        head_sha: "b8f95242",
        repo: {"full_name" => "author/repo", "default_branch" => "master"},
        state: :in_progress
      )
      CoverageCheck.create!(
        installation:,
        head_sha: "b8f95243",
        repo: {"full_name" => "author/repo", "default_branch" => "master"},
        state: :in_progress
      )
      expect(CoverageCheck.in_progress_for_installation(installation).count).to eq(2)
    end
  end

  describe "#to_chartkick" do
    it "is empty without records" do
      expect(described_class.to_chartkick).to eq({})
    end

    it "returns a valid datapoint array" do
      user = User.create!(
        uid: "1337",
        email: "foo@bar.com",
        token: "sekritkey",
        name: "Foo Bar"
      )
      installation = Installation.create!(installation_id: "123123", users: [user])
      CoverageCheck.create!(
        installation:,
        head_sha: "953a804",
        repo: {"full_name" => "author/repo", "default_branch" => "master"},
        state: "complete",
        result: "passed"
      )
      CoverageCheck.create!(
        installation:,
        head_sha: "953a805",
        repo: {"full_name" => "author/repo", "default_branch" => "master"},
        state: "complete",
        result: "failed"
      )
      expect(described_class.to_chartkick).to match(
        {
          ["failed", Date.today] => 1,
          ["passed", Date.today] => 1
        }
      )
    end
  end
end

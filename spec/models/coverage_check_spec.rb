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
end

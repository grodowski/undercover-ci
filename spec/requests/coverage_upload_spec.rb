# frozen_string_literal: true

require "base64"
require "rails_helper"

describe "Coverage Upload" do
  # FIXME: repo + sha params
  # FIXME: authenticate
  def path(id)
    "/v1/runs/#{id}/coverage.json"
  end

  it "renders 404 when CoverageReportJob does not exist" do
    expect { post path(7) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "stores the LCOV in active storage" do
    crj = CoverageReportJob.create
    contents = File.read("spec/fixtures/coverage.lcov")

    fake_run = class_spy(Logic::RunUndercover)
    stub_const("Logic::RunUndercover", fake_run)

    post path(crj.id), params: {lcov_base64: Base64.encode64(contents)}

    crj.reload
    expect(crj.coverage_reports).not_to be_empty

    expect(crj.coverage_reports.attachments.first.download).to eq(contents)
    expect(response.status).to eq(201)
  end

  it "validates uploads" do
    crj = CoverageReportJob.create
    contents = File.read("public/404.html") # text/html, should fail

    post path(crj.id), params: {lcov_base64: Base64.encode64(contents)}

    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)).to eq(
      "error" => "could not recognise '<!DOCTYPE html>\n' as valid LCOV"
    )
    expect(crj.reload.coverage_reports.attached?).to eq(false)
  end

  it "kicks off RunUndercover" do
    crj = CoverageReportJob.create
    contents = File.read("spec/fixtures/coverage.lcov")

    fake_run = class_spy(Logic::RunUndercover)
    stub_const("Logic::RunUndercover", fake_run)

    post path(crj.id), params: {lcov_base64: Base64.encode64(contents)}

    expect(fake_run).to have_received(:call)
  end
end

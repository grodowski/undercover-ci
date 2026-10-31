# frozen_string_literal: true

require "rails_helper"

describe "/docs" do
  before { get "/docs" }

  it "renders the view coverage section" do
    expect(response.status).to eq(200)
    expect(response.body).to include('id="view-coverage"')
    expect(response.body).to include('href="#view-coverage"')
    expect(response.body).to include("enable_coverage(:eval)")
    expect(response.body).to include("-f *.rb,*.rake,*.ru,Rakefile,*.erb")
  end

  it "documents undercover 0.9 configuration changes" do
    expect(response.body).to include("# simplecov:disable")
    expect(response.body).to include("relative to the directory SimpleCov covered")
  end
end

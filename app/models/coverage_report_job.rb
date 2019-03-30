# frozen_string_literal: true

class CoverageReportJob < ApplicationRecord
  has_many_attached :coverage_reports

  after_initialize do
    self.event_log ||= []
  end

  def repo_full_name
    repo["full_name"]
  end
end

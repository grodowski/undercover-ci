# frozen_string_literal: true

class CoverageReportJob < ApplicationRecord
  after_initialize do
    self.event_log ||= []
  end
end

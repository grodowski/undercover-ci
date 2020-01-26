# frozen_string_literal: true

class CoverageCheck < ApplicationRecord
  belongs_to :installation
  has_many :nodes

  has_many_attached :coverage_reports

  validates :state, inclusion: {in: %i[created awaiting_coverage in_progress complete]}

  after_initialize do
    self.state ||= :created
    self.event_log ||= []
    self.state_log ||= []
  end

  def state
    super&.to_sym
  end

  def repo_full_name
    repo["full_name"]
  end

  def default_branch
    repo["default_branch"]
  end

  def pull_requests
    return [] unless check_suite

    check_suite["pull_requests"]
  end
end

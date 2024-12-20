# frozen_string_literal: true

class CoverageCheck < ApplicationRecord
  belongs_to :installation
  has_many :nodes

  has_many_attached :coverage_reports

  scope :with_counts, (lambda do
    select <<~SQL
      coverage_checks.*,
      (
        SELECT COUNT(nodes.id) FROM nodes
        WHERE coverage_check_id = coverage_checks.id
      ) AS nodes_count,
      (
        SELECT COUNT(nodes.id) FROM nodes
        WHERE coverage_check_id = coverage_checks.id AND flagged = TRUE
      ) AS flagged_nodes_count
    SQL
  end)

  scope :in_progress_for_installation, (lambda do |installation_id|
    where(installation_id:, state: :in_progress)
  end)

  validates :state, inclusion: {
    in: %i[created awaiting_coverage queued in_progress complete canceled]
  }

  after_initialize do
    self.state ||= :created
    self.event_log ||= []
    self.state_log ||= []
    self.repo ||= {}
  end

  delegate :max_concurrent_checks, to: :installation

  def installation_active?
    return true if repo_public?

    installation.active?
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

  def repo_public?
    repo["visibility"] == "public"
  end

  def pull_requests
    return [] unless check_suite

    check_suite["pull_requests"]
  end
end

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
  scope :complete, -> { where(state: :complete) }
  scope :last_90d, -> { where("coverage_checks.created_at > ?", 90.days.ago.beginning_of_day) }
  scope :last_30d, -> { where("coverage_checks.created_at > ?", 30.days.ago.beginning_of_day) }
  scope :last_7d, -> { where("coverage_checks.created_at > ?", 7.days.ago.beginning_of_day) }

  validates :state, inclusion: {
    in: %i[created awaiting_coverage queued in_progress complete canceled]
  }
  validates :result, inclusion: {in: %i[passed failed]}, allow_nil: true

  after_initialize do
    self.state ||= :created
    self.event_log ||= []
    self.state_log ||= []
    self.repo ||= {}
  end

  delegate :max_concurrent_checks, to: :installation

  def self.to_chartkick
    group(:result).group_by_day(:created_at).count
  end

  def installation_active?
    return true if repo_public?

    installation.active?
  end

  def state
    super&.to_sym
  end

  def result
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

  def base_ref_or_branch
    base_sha.try(:[], 0..7) || default_branch
  end
end

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

  def self.for_repo_sha(repo_full_name, sha)
    where("repo @> ?", {full_name: repo_full_name}.to_json).find_by(head_sha: sha)
  end

  # Serializes check creation for a commit between the check_suite webhook and coverage uploads.
  # Call inside a transaction, the lock is released on commit.
  def self.lock_repo_sha(repo_full_name, sha)
    connection.execute(sanitize_sql_array(["SELECT pg_advisory_xact_lock(hashtext(?))", "#{repo_full_name}@#{sha}"]))
  end

  def self.to_chartkick
    group(:result).group_by_day(:created_at).count
  end

  def installation_active?
    return true if repo_public?

    installation.active?
  end

  def expire_check_wait
    return ExpireCheckJob::INACTIVE_WAIT unless installation_active?
    return installation.expire_check_job_wait_minutes.minutes if installation.expire_check_job_wait_minutes

    ExpireCheckJob::DEFAULT_WAIT
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

  # The default branch, when an upload-created check had no valid target branch to compare against
  def compare_fallback
    default_branch if pull_request_number && base_sha.blank?
  end

  # an upload-created check has no check_suite, only the branch name the uploader sent
  def head_branch
    check_suite&.dig("head_branch") || pull_request_head_ref
  end

  def pull_requests
    return [] unless check_suite

    check_suite["pull_requests"]
  end

  def base_ref_or_branch
    return default_branch if base_sha.blank?

    base_sha.match?(/\A\h{40}\z/) ? base_sha[0..7] : base_sha
  end

  def failure_mode
    installation.repo_failure_modes[repo_full_name]
  end
end

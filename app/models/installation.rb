# frozen_string_literal: true

class Installation < ApplicationRecord
  has_many :user_installations
  has_many :users, through: :user_installations
  has_many :coverage_checks

  has_many :subscriptions

  validates_presence_of :installation_id
  validate :critical_paths_within_limits

  DEFAULTS = {max_concurrent_checks: ENV.fetch("DEFAULT_MAX_CONCURRENT_CHECKS", 2).to_i}.freeze
  MAX_CRITICAL_PATHS = 50
  MAX_CRITICAL_PATH_LENGTH = 200
  store_accessor :settings,
                 :expire_check_job_wait_minutes,
                 :max_concurrent_checks,
                 :repo_branch_filters,
                 :repo_failure_modes,
                 :repo_critical_paths

  after_create :ensure_subscription
  after_create_commit :notify_admin

  def github_type
    return unless metadata.present?

    metadata["target_type"].downcase
  end

  def org?
    github_type == "organization"
  end

  def user?
    github_type == "user"
  end

  def repo_names
    (repos || []).map { it["full_name"] }
  end

  def subscription
    subscriptions.last
  end

  def active?
    return true unless subscription

    subscription.active?
  end

  def notify_admin
    AdminMailer.new_installation(self).deliver_later
  end

  def ensure_subscription
    return if user? || subscription.present?

    subscriptions.create
  end

  def max_concurrent_checks
    (super || DEFAULTS[:max_concurrent_checks]).to_i
  end

  def branch_matches_filter?(branch_name, repo_full_name = nil)
    return true unless repo_full_name && repo_branch_filters.present?

    repo_filter = repo_branch_filters[repo_full_name]
    return true unless repo_filter.present?

    begin
      Regexp.new(repo_filter).match?(branch_name)
    rescue RegexpError
      true
    end
  end

  def repo_branch_filters = super || {}
  def repo_failure_modes = super || {}
  def repo_critical_paths = super || {}

  def set_repo_failure_mode(repo_full_name, failure_mode)
    failure_mode = failure_mode&.to_sym || :failure

    modes = repo_failure_modes.dup
    modes[repo_full_name] = failure_mode
    self.repo_failure_modes = modes
  end

  def set_repo_branch_filter(repo_full_name, filter_regex)
    filters = repo_branch_filters.dup
    if filter_regex.present?
      filters[repo_full_name] = filter_regex.strip
    else
      filters.delete(repo_full_name)
    end
    self.repo_branch_filters = filters
  end

  def set_repo_critical_paths(repo_full_name, text)
    globs = text.to_s.lines.map(&:strip).reject { it.empty? || it.start_with?("#") }.uniq
    paths = repo_critical_paths.dup
    if globs.any?
      paths[repo_full_name] = globs
    else
      paths.delete(repo_full_name)
    end
    self.repo_critical_paths = paths
  end

  private

  def critical_paths_within_limits
    return if repo_critical_paths.values.all? do |globs|
      globs.size <= MAX_CRITICAL_PATHS && globs.all? { it.size <= MAX_CRITICAL_PATH_LENGTH }
    end

    errors.add(
      :base,
      "Critical paths are limited to #{MAX_CRITICAL_PATHS} patterns of up to #{MAX_CRITICAL_PATH_LENGTH} characters"
    )
  end
end

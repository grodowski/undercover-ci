# frozen_string_literal: true

class Installation < ApplicationRecord
  has_many :user_installations
  has_many :users, through: :user_installations
  has_many :coverage_checks

  has_many :subscriptions

  validates_presence_of :installation_id

  DEFAULTS = {max_concurrent_checks: ENV.fetch("DEFAULT_MAX_CONCURRENT_CHECKS", 2).to_i}.freeze
  store_accessor :settings,
                 :expire_check_job_wait_minutes,
                 :max_concurrent_checks,
                 :repo_branch_filters,
                 :repo_failure_modes

  after_create :ensure_subscription

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
    (repos || []).map { _1["full_name"] }
  end

  def subscription
    subscriptions.last
  end

  def active?
    return true unless subscription

    subscription.active?
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
end

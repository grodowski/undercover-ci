# frozen_string_literal: true

class Installation < ApplicationRecord
  has_many :user_installations
  has_many :users, through: :user_installations
  has_many :coverage_checks

  has_many :subscriptions

  validates_presence_of :installation_id

  DEFAULTS = {max_concurrent_checks: ENV.fetch("DEFAULT_MAX_CONCURRENT_CHECKS", 2).to_i}.freeze
  store_accessor :settings, :expire_check_job_wait_minutes, :max_concurrent_checks

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
end

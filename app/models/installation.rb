# frozen_string_literal: true

class Installation < ApplicationRecord
  has_many :user_installations
  has_many :users, through: :user_installations
  has_many :coverage_checks

  has_many :subscriptions

  validates_presence_of :installation_id

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

  def subscription
    subscriptions.last
  end

  def active?
    return true unless ENV["FF_SUBSCRIPTION"]
    return true unless subscription

    subscription.active?
  end

  def ensure_subscription
    return unless ENV["FF_SUBSCRIPTION"]
    return if user? || subscription.present?

    subscriptions.create
  end
end

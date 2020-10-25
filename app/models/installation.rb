# frozen_string_literal: true

class Installation < ApplicationRecord
  has_many :user_installations
  has_many :users, through: :user_installations
  has_many :coverage_checks

  has_many :subscriptions

  validates_presence_of :installation_id

  def github_type
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
    subscription.active?
  end
end

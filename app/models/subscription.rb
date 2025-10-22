# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :installation

  validates :gumroad_id, :license_key, presence: true, if: -> { state == :subscribed }
  validates :state, inclusion: {in: %i[beta unsubscribed subscribed]}

  scope :active, -> { where("end_date IS NULL or end_date > ?", Time.now) }

  after_initialize do
    self.state ||= :unsubscribed
    self.state_log ||= []
  end

  def state
    super&.to_sym
  end

  def active?
    case state
    when :beta, :subscribed
      true
    when :unsubscribed
      return Time.now < end_date if end_date

      Time.now < trial_expiry_date
    end
  end

  def trial_expiry_date
    (created_at + 14.days).end_of_day
  end

  def trial?
    state == :unsubscribed && end_date.blank?
  end

  def license_key
    return "BETA" if state == :beta

    super
  end
end

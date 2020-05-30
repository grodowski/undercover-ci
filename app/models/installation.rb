# frozen_string_literal: true

class Installation < ApplicationRecord
  has_many :user_installations
  has_many :users, through: :user_installations
  has_many :coverage_checks

  validates_presence_of :installation_id
end

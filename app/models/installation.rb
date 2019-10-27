# frozen_string_literal: true

class Installation < ApplicationRecord
  belongs_to :user
  has_many :coverage_checks

  validates_presence_of :installation_id
end

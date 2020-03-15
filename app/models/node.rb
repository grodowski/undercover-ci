# frozen_string_literal: true

class Node < ApplicationRecord
  belongs_to :coverage_check

  scope :flagged, -> { where(flagged: true) }
end

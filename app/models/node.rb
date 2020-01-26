# frozen_string_literal: true

class Node < ApplicationRecord
  belongs_to :coverage_check
end

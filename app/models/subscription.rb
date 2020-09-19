# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :installation
end

# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.var_1 = Rails.env.production? && "yes"
  self.var_2 = Rails.env.development? && "no"
end

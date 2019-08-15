# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def untested
    puts "one"
    puts "two"
    puts "three"
  end
end

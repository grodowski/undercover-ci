# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def test_method
    puts "untested!"
    puts "a"
    puts "c"
    puts "more untested"
  end
end

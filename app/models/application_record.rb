# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  
  def untested2
    puts `echo lol`
  end
  
  def untested
    puts "one"
    puts "two"
    puts "three"
    puts "four"
  end
end

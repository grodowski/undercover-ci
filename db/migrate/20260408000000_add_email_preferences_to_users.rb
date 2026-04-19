# frozen_string_literal: true

class AddEmailPreferencesToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :email_preferences, :jsonb, default: {}
  end
end

# frozen_string_literal: true

class UserInstallation < ApplicationRecord
  belongs_to :user
  belongs_to :installation
end

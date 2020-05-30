class UserInstallation < ApplicationRecord
  belongs_to :user
  belongs_to :installation
end

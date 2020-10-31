# frozen_string_literal: true

desc "Refresh all Gumroad license keys"
task refresh_licenses: :environment do
  Gumroad::ValidateAll.call
end

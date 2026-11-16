# frozen_string_literal: true

class AddInstallationIdCreatedAtIndexToCoverageChecks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :coverage_checks, %i[installation_id created_at], algorithm: :concurrently
  end
end

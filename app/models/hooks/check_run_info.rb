# frozen_string_literal: true

require "ostruct"

module Hooks
  CheckRunInfo = Struct.new(:full_name, :sha, :installation_id) do
    def self.from_webhook(payload)
      payload = OpenStruct.new(payload)
      installation_id = payload.installation.fetch("id")
      full_name = payload.repository.fetch("full_name")
      sha = payload.check_suite.fetch("head_sha")
      new(full_name, sha, installation_id)
    end

    def self.build_from_hash(check_run_info_hash)
      new(
        check_run_info_hash.fetch(:full_name),
        check_run_info_hash.fetch(:sha),
        check_run_info_hash.fetch(:installation_id)
      )
    end

    alias_method :to_s, :inspect
  end
end

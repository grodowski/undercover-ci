# frozen_string_literal: true

require "ostruct"

module Hooks
  class CheckRunInfo
    attr_reader :installation_id, :full_name, :sha
    attr_accessor :payload

    def self.from_webhook(payload)
      payload = OpenStruct.new(payload)
      installation_id = payload.installation.fetch("id")
      full_name = payload.repository.fetch("full_name")
      sha = payload.check_suite.fetch("head_sha")
      new(full_name, sha, installation_id).tap do |info|
        info.payload = payload
      end
    end

    def initialize(full_name, sha, installation_id)
      @full_name = full_name
      @sha = sha
      @installation_id = installation_id
    end

    def to_h
      @payload.to_h
    end
  end
end

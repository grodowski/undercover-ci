# frozen_string_literal: true

require "ostruct"

module Hooks
  class CheckRunInfo
    attr_reader :installation_id, :full_name, :sha

    def initialize(payload)
      @payload = OpenStruct.new(payload)
      @installation_id = @payload.installation.fetch("id")
      @full_name = @payload.repository.fetch("full_name")
      @sha = @payload.check_suite.fetch("head_sha")
    end

    def to_h
      @payload.to_h
    end
  end
end

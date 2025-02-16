# frozen_string_literal: true

module Dashboard
  class ChartsController < ApplicationController
    include Chartable

    RESULT_COLORS = {
      passed: "green",
      failed: "orange"
    }.freeze

    def total_checks
      render json: chart_json(filter_checks_from_params.complete.to_chartkick)
    end

    private

    # stolen from chartkick's lib/chartkick/core_ext.rb, adds the colours
    def chart_json(hash)
      if (key = hash.keys.first) && key.is_a?(Array) && key.size == 2
        hash.group_by { |k, _v| k.first }.map do |name, data|
          {name:, color: RESULT_COLORS[name.to_sym], data: data.map { |k, v| [k[1], v] }}
        end
      else
        hash.to_a
      end.to_json
    end
  end
end

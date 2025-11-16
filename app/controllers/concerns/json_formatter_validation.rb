# frozen_string_literal: true

module JsonFormatterValidation
  extend ActiveSupport::Concern

  Invalid = Class.new(StandardError)
  ERROR_HELP = "Did you use SimpleCov::Formatter::Undercover?"

  included do
    private

    def validate_formatted_json(input_json)
      missing_keys = %w[meta coverage] - input_json.keys
      raise Invalid, "Missing JSON keys: #{missing_keys.join(', ')}. #{ERROR_HELP}" if missing_keys.any?

      return if input_json["coverage"].values.all? { _1.is_a?(Hash) && _1.key?("lines") }

      raise Invalid, "Missing/malformed coverage data. #{ERROR_HELP}"
    end
  end
end

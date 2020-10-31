# frozen_string_literal: true

module Logic
  Status = Struct.new(:error) do
    def success?
      error.blank?
    end

    def error?
      error.present?
    end
  end
end

# frozen_string_literal: true

module ClassLoggable
  def log(message, level = :info)
    Rails.logger.public_send(level, "[#{self.class}] #{message}")
  end
end

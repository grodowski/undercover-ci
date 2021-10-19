# frozen_string_literal: true

require "ostruct"

module DataObjects
  module Gumroad
    Sale = Class.new(OpenStruct) do
      alias_method :to_s, :inspect

      def valid_request?
        seller_id == ::Gumroad::SELLER_ID
      end

      def installation_id
        url_params["installation_id"]
      end
    end

    LicenseKey = Class.new(OpenStruct) do
      def active?
        return false unless success

        purchase["permalink"] == ::Gumroad::SUBSCRIPTION_PRODUCT_PERMALINK &&
          cancelled_at.blank? && failed_at.blank?
      end

      def failed_at
        purchase["subscription_failed_at"]&.to_time
      end

      def cancelled_at
        purchase["subscription_cancelled_at"]&.to_time
      end
    end
  end
end

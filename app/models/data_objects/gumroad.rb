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
        url_params.fetch("installation_id")
      end
    end

    LicenseKey = Class.new(OpenStruct) do
      def active?
        return false unless success

        purchase["permalink"] == ::Gumroad::SUBSCRIPTION_PRODUCT_PERMALINK &&
          purchase["subscription_cancelled_at"].blank? &&
          purchase["subscription_failed_at"].blank?
      end
    end
  end
end

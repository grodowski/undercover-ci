# frozen_string_literal: true

require "uri"
require "net/http"

module Gumroad
  RequestError = Class.new(StandardError)

  class ValidateLicense
    include ClassLoggable

    def initialize(license_key)
      @license_key = license_key
    end

    attr_reader :license_key, :license

    def call
      @res = Net::HTTP.post(
        URI("https://api.gumroad.com/v2/licenses/verify"),
        {product_permalink: Gumroad::SUBSCRIPTION_PRODUCT_PERMALINK, license_key: license_key}.to_query
      )
      case @res.code.to_i
      when 200
        license_valid?
      when 404
        license_not_found
      else
        raise RequestError, "#{@res.code} #{@res.body}"
      end
    end

    private

    def license_valid?
      @license = DataObjects::Gumroad::LicenseKey.new(JSON.parse(@res.body))
      Logic::Status.new(@license.active? ? nil : "inactive license key")
    end

    def license_not_found
      @license = DataObjects::Gumroad::LicenseKey.new(JSON.parse(@res.body))
      Logic::Status.new(@license.message)
    end
  end
end

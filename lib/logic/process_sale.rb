# frozen_string_literal: true

module Logic
  class ProcessSale
    include ClassLoggable

    Error = Class.new(StandardError)

    def self.call(gumroad_sale)
      new(gumroad_sale).call
    end

    def initialize(gumroad_sale)
      @sale = gumroad_sale
      @installation = Installation.find_by!(installation_id: gumroad_sale.installation_id)
    end

    attr_reader :sale, :installation, :error

    def call
      Installation.transaction do
        error = check_subscription
        if error
          Sentry.capture_exception(Error.new("#{sale.subscription_id} error: #{error}"))
          return Status.new(error)
        end

        installation.subscriptions.create!(
          gumroad_id: @sale.subscription_id,
          license_key: @sale.license_key,
          end_date: nil,
          state: :subscribed
        )
      end
      Status.new(nil)
    end

    private

    def check_subscription
      return "license key already used" if Subscription.where(license_key: sale.license_key).exists?

      validator_status = Gumroad::ValidateLicense.new(sale.license_key).call
      return if validator_status.success?

      "gumroad license error, #{validator_status.error}"
    end
  end
end

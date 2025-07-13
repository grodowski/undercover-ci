# frozen_string_literal: true

module V1
  class GumroadPingController < ApiController
    skip_before_action :verify_authenticity_token

    # :nocov:
    def create
      sale = DataObjects::Gumroad::Sale.new(params)
      unless sale.valid_request?
        head :forbidden
        return
      end
      if sale.installation_id
        Logic::ProcessSale.call(sale)
      elsif sale.license_key
        unless Subscription.active.where(license_key: sale.license_key).exists?
          Sentry.add_breadcrumb(Sentry::Breadcrumb.new(category: "ping_params", message: params))
          Sentry.capture_exception(Logic::ProcessSale::Error.new("ping: unknown or inactive #{sale.license_key}"))
        end
      end
      head :ok
    end
    # :nocov:
  end
end

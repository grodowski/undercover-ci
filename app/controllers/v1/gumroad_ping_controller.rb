# frozen_string_literal: true

module V1
  class GumroadPingController < ApiController
    skip_before_action :verify_authenticity_token

    def create
      sale = DataObjects::Gumroad::Sale.new(params)
      unless sale.valid_request?
        head :forbidden
        return
      end
      Logic::ProcessSale.call(sale) if sale.installation_id
      head :ok
    end
  end
end

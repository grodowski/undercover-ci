# frozen_string_literal: true

module V1
  class GumroadPingController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      sale = DataObjects::Gumroad::Sale.new(params)
      unless sale.valid_request?
        head :forbidden
        return
      end
      Logic::ProcessSale.call(sale)
      head :ok
    end
  end
end

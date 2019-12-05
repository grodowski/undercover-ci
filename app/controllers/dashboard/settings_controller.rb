# frozen_string_literal: true

module Dashboard
  class SettingsController < ApplicationController
    before_action :check_current_user
    before_action :validate_installations, except: :new

    def index
      @installations = current_user.installations
      @show_coverage_upload_instruction = current_user.coverage_checks.none?
    end
  end
end

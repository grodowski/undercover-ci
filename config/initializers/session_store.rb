# frozen_string_literal: true

Rails.application.config.session_store :cookie_store, key: "_undercover_ci_session_#{Rails.env}", domain: :all

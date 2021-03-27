# frozen_string_literal: true

module Gumroad
  module ValidateAll
    extend ClassLoggable

    def self.call
      Subscription.where("license_key IS NOT NULL").find_each { |s| validate(s) }
    end

    def self.validate(subscription)
      validator = ValidateLicense.new(subscription.license_key)
      status = validator.call
      installation_id = subscription.installation.installation_id

      if status.error?
        log "key:#{subscription.license_key} installation:#{installation_id} error:#{status.error}"
        if validator.license.cancelled_at
          Logic::UpdateSubscriptionState.new(subscription).unsubscribe(
            validator.license.cancelled_at
          )
        end
        if validator.license.failed_at
          Raven.capture_exception(
            "#{subscription.gumroad_id} license validation" \
                        " - payment failed on #{validator.license.failed_at}"
          )
        end
      else
        log "key:#{subscription.license_key} installation:#{installation_id}, ok:#{status.success?}"
      end
    end

    def self.log(msg)
      puts "[#{name}] #{msg}"
      super msg
    end
  end
end

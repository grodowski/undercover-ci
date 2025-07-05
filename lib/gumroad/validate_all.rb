# frozen_string_literal: true

# :nocov:
module Gumroad
  module ValidateAll
    extend ClassLoggable

    def self.call
      Subscription.where("license_key IS NOT NULL").find_each { |s| validate(s) }
    end

    def self.validate(subscription)
      return if subscription.state == :beta

      validator = ValidateLicense.new(subscription.license_key)
      status = validator.call
      installation_id = subscription.installation.installation_id

      if status.error?
        log "key:#{subscription.license_key} installation:#{installation_id} " \
            "error:#{status.error} license:#{validator.license}"
        if validator.license.cancelled_at || validator.license.failed_at
          log("cancelled_at: #{validator.license.failed_at}")
          if subscription.state != :unsubscribed
            Sentry.capture_exception(
              Gumroad::LicenseInvalid.new(
                "installation:#{installation_id}, gumroad:#{subscription.gumroad_id} license validation " \
                "- payment failed at #{validator.license.failed_at}"
              )
            )
          end
          Logic::UpdateSubscriptionState.new(subscription).unsubscribe(validator.license.failed_at)
        end
      else
        log "key:#{subscription.license_key} installation:#{installation_id}, ok:#{status.success?}"
      end
    end

    def self.log(msg)
      puts "[#{name}] #{msg}"
      super
    end
  end
end
# :nocov:

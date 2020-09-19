# frozen_string_literal: true

module Logic
  class UpdateSubscriptionState < StateMachine
    def subscribe
      transition(%i[beta unsubscribed], :subscribed)
    end

    def unsubscribe
      transition(:subscribed, :unsubscribed)
    end

    # TODO: unlimited - manual state
  end
end

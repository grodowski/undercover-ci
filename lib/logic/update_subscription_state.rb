# frozen_string_literal: true

module Logic
  class UpdateSubscriptionState < StateMachine
    def subscribe
      transition(%i[beta unsubscribed], :subscribed)
    end

    def unsubscribe
      transition(:subscribed, :unsubscribed)
    end

    def end_beta
      transition(:beta, :unsubscribed)
    end
  end
end

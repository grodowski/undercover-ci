# frozen_string_literal: true

module Logic
  class UpdateSubscriptionState < StateMachine
    def subscribe
      transition(%i[beta unsubscribed], :subscribed)
    end

    def unsubscribe(end_date)
      record.transaction do
        record.end_date = end_date
        transition(:subscribed, :unsubscribed)
      end
    end

    def end_beta
      transition(:beta, :unsubscribed)
    end
  end
end

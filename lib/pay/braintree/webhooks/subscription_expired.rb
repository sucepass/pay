# A subscription reaches the specified number of billing cycles and expires.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionExpired
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:braintree, subscription.id)
          return unless pay_subscription.present?

          pay_subscription.update!(ends_at: Time.current, status: :canceled)
        end
      end
    end
  end
end

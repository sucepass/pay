module Pay
  module Paddle
    autoload :Billable, "pay/paddle/billable"
    autoload :Charge, "pay/paddle/charge"
    autoload :Subscription, "pay/paddle/subscription"
    autoload :Error, "pay/paddle/error"

    module Webhooks
      autoload :SignatureVerifier, "pay/paddle/webhooks/signature_verifier"
      autoload :SubscriptionCreated, "pay/paddle/webhooks/subscription_created"
      autoload :SubscriptionCancelled, "pay/paddle/webhooks/subscription_cancelled"
      autoload :SubscriptionPaymentRefunded, "pay/paddle/webhooks/subscription_payment_refunded"
      autoload :SubscriptionPaymentSucceeded, "pay/paddle/webhooks/subscription_payment_succeeded"
      autoload :SubscriptionUpdated, "pay/paddle/webhooks/subscription_updated"
    end

    extend Env

    def self.setup
      ::PaddlePay.config.vendor_id = vendor_id
      ::PaddlePay.config.vendor_auth_code = vendor_auth_code

      configure_webhooks
    end

    def self.vendor_id
      find_value_by_name(:paddle, :vendor_id)
    end

    def self.vendor_auth_code
      find_value_by_name(:paddle, :vendor_auth_code)
    end

    def self.public_key_base64
      find_value_by_name(:paddle, :public_key_base64)
    end

    def self.passthrough(owner:, **options)
      options.merge(owner_sgid: owner.to_sgid.to_s).to_json
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "paddle.subscription_created", Pay::Paddle::Webhooks::SubscriptionCreated.new
        events.subscribe "paddle.subscription_updated", Pay::Paddle::Webhooks::SubscriptionUpdated.new
        events.subscribe "paddle.subscription_cancelled", Pay::Paddle::Webhooks::SubscriptionCancelled.new
        events.subscribe "paddle.subscription_payment_succeeded", Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new
        events.subscribe "paddle.subscription_payment_refunded", Pay::Paddle::Webhooks::SubscriptionPaymentRefunded.new
      end
    end
  end
end

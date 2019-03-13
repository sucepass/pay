require 'stripe_event'
Dir[File.join(__dir__, 'webhooks', '**', '*.rb')].each { |file| require file }

env         = Rails.env.to_sym
secrets     = Rails.application.secrets
credentials = Rails.application.credentials

StripeEvent.signing_secret = ENV["STRIPE_SIGNING_SECRET"] || secrets.dig(env, :stripe, :signing_secret) || credentials.dig(env, :stripe, :signing_secret)

StripeEvent.configure do |events|
  # Listen to the charge event to make sure we get non-subscription
  # purchases as well. Invoice is only for subscriptions and manual creation
  # so it does not include individual charges.
  events.subscribe 'charge.succeeded', Pay::Stripe::Webhooks::ChargeSucceeded.new
  events.subscribe 'charge.refunded', Pay::Stripe::Webhooks::ChargeRefunded.new

  # Warn user of upcoming charges for their subscription. This is handy for
  # notifying annual users their subscription will renew shortly.
  # This probably should be ignored for monthly subscriptions.
  events.subscribe 'invoice.upcoming', Pay::Stripe::Webhooks::SubscriptionRenewing.new

  # If a subscription is manually created on Stripe, we want to sync
  events.subscribe 'customer.subscription.created', Pay::Stripe::Webhooks::SubscriptionCreated.new

  # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
  events.subscribe 'customer.subscription.updated', Pay::Stripe::Webhooks::SubscriptionUpdated.new

  # When a customers subscription is canceled, we want to update our records
  events.subscribe 'customer.subscription.deleted', Pay::Stripe::Webhooks::SubscriptionDeleted.new

  # Monitor changes for customer's default card changing
  events.subscribe 'customer.updated', Pay::Stripe::Webhooks::CustomerUpdated.new

  # If a customer was deleted in Stripe, their subscriptions should be cancelled
  events.subscribe 'customer.deleted', Pay::Stripe::Webhooks::CustomerDeleted.new

  # If a customer's payment source was deleted in Stripe, we should update as well
  events.subscribe 'customer.source.deleted', Pay::Stripe::Webhooks::SourceDeleted.new
end

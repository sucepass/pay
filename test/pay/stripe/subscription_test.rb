require "test_helper"

class Pay::Stripe::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe)
  end

  test "change stripe subscription quantity" do
    @user.card_token = "pm_card_visa"
    subscription = @user.subscribe(name: "default", plan: "default")
    subscription.change_quantity(5)
    stripe_subscription = subscription.processor_subscription
    assert_equal 5, stripe_subscription.quantity
    assert_equal 5, subscription.quantity
  end
end

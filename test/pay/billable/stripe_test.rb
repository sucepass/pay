require "test_helper"

class Pay::Stripe::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "johnny@appleseed.com"
    @billable.processor = "stripe"

    @customer = ::Stripe::Customer.create(email: @billable.email)

    @plan = ::Stripe::Plan.retrieve("small-monthly")
  end

  test "getting a stripe customer with a processor id" do
    @billable.processor_id = @customer.id
    assert_equal @billable.stripe_customer, @customer
  end

  test "getting a stripe customer without a processor id" do
    assert_nil @billable.processor_id

    @billable.card_token = payment_method.id
    @billable.stripe_customer

    assert_not_nil @billable.processor_id
    assert @billable.card_type == "Visa"
    assert @billable.card_last4 == "4242"
  end

  test "can create a charge" do
    @billable.card_token = payment_method.id

    charge = @billable.charge(2900)
    assert_equal Pay::Charge, charge.class
    assert_equal 2900, charge.amount
  end

  test "handles stripe card declined" do
    @billable.card_token = "pm_card_chargeDeclined"
    assert_raises(Pay::Stripe::Error) { @billable.charge(2900) }
  end

  test "raises action required error when SCA required" do
    exception = assert_raises(Pay::ActionRequired) {
      @billable.card_token = sca_payment_method.id
      @billable.charge(2900)
    }
    assert_equal "This payment attempt failed because additional action is required before it can be completed.", exception.message
  end

  test "can create a subscription" do
    @billable.card_token = payment_method.id
    @billable.subscribe(name: "default", plan: "small-monthly")

    assert @billable.subscribed?
    assert_equal "default", @billable.subscription.name
    assert_equal "small-monthly", @billable.subscription.processor_plan
  end

  test "can swap a subscription" do
    @billable.card_token = payment_method.id
    subscription = @billable.subscribe(name: "default", plan: "small-monthly")
    subscription.swap("small-annual")
    assert @billable.subscribed?
    assert_equal "default", @billable.subscription.name
    assert_equal "small-annual", @billable.subscription.processor_plan
  end

  test "fails when subscribing with no payment method" do
    exception = assert_raises(Pay::Stripe::Error) {
      @billable.subscribe(name: "default", plan: "small-monthly")
    }
    assert_equal "This customer has no attached payment source or default payment method.", exception.message
  end

  test "fails when subscribing with SCA card" do
    exception = assert_raises(Pay::ActionRequired) {
      @billable.card_token = sca_payment_method.id
      @billable.subscribe(name: "default", plan: "small-monthly")
    }

    assert_equal "This payment attempt failed because additional action is required before it can be completed.", exception.message
  end

  test "can update their card" do
    @billable.update_card(payment_method.id)

    assert_equal "Visa", @billable.card_type
    assert_equal "4242", @billable.card_last4
    assert_nil @billable.card_token

    payment_method = create_payment_method(card: {number: "6011 1111 1111 1117"})
    @billable.update_card(payment_method.id)

    assert @billable.card_type == "Discover"
    assert @billable.card_last4 == "1117"
  end

  test "retriving a stripe subscription" do
    @billable.processor_id = @customer.id
    @billable.update_card(payment_method.id)
    subscription = ::Stripe::Subscription.create(plan: "small-monthly", customer: @customer.id)
    assert_equal @billable.stripe_subscription(subscription.id), subscription
  end

  test "can create an invoice" do
    @billable.processor_id = @customer.id
    @billable.update_card(payment_method.id)

    ::Stripe::InvoiceItem.create(
      customer: @customer.id,
      amount: 1000,
      currency: "usd",
      description: "One-time setup fee"
    )

    assert_equal 1000, @billable.invoice!.total
  end

  test "card gets updated automatically when retrieving customer" do
    assert_nil @billable.card_type

    @billable.processor = "stripe"
    @billable.processor_id = @customer.id

    assert_equal @billable.customer, @customer

    @billable.card_token = payment_method.id

    # This should trigger update_card
    assert_equal @billable.customer, @customer
    assert_equal @billable.card_type, "Visa"
    assert_equal @billable.card_last4, "4242"
  end

  test "creating a stripe customer with no card" do
    @billable.customer

    assert_nil @billable.card_last4
    assert_equal @billable.processor, "stripe"
    assert_not_nil @billable.processor_id
  end

  test "email changed" do
    # Must already have a processor ID
    @billable.customer # Sets customer ID
    Pay::EmailSyncJob.expects(:perform_later).with(@billable.id, @billable.class.name)
    @billable.update(email: "mynewemail@example.org")
  end

  test "handles exception when creating a customer" do
    @billable.card_token = "invalid"
    exception = assert_raises(Pay::Stripe::Error) { @billable.stripe_customer }
    assert_equal "No such PaymentMethod: 'invalid'", exception.message
  end

  test "handles exception when creating a charge" do
    exception = assert_raises(Pay::Stripe::Error) { @billable.charge(0) }
    assert_equal "This value must be greater than or equal to 1.", exception.message
  end

  test "handles exception when creating a subscription" do
    exception = assert_raises(Pay::Stripe::Error) { @billable.subscribe plan: "invalid" }
    assert_equal "No such plan: 'invalid'", exception.message
  end

  test "handles exception when updating a card" do
    exception = assert_raises(Pay::Stripe::Error) { @billable.update_card("abcd") }
    assert_equal "No such PaymentMethod: 'abcd'", exception.message
  end

  test "handles coupons" do
    @billable.card_token = payment_method.id
    subscription = @billable.subscribe(plan: "small-monthly", coupon: "10BUCKS")
    assert_equal "10BUCKS", subscription.processor_subscription.discount.coupon.id
  end

  test "stripe trial period options" do
    travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
      @billable.card_token = payment_method.id
      subscription = @billable.subscribe(plan: "small-monthly", trial_period_days: 15)
      assert_equal "trialing", subscription.status
      assert_not_nil subscription.trial_ends_at
      assert subscription.trial_ends_at > 14.days.from_now
    end
  end

  test "can create setup intent" do
    assert_nothing_raised do
      @billable.create_setup_intent
    end
  end

  test "can pass shipping information to charge" do
    @billable.card_token = payment_method.id
    charge = @billable.charge(25_00, shipping: {
      name: "Recipient",
      address: {
        line1: "One Infinite Loop",
        city: "Cupertino",
        state: "CA"
      }
    })

    assert_equal "Cupertino", charge.processor_charge.shipping.address.city
  end

  test "allows subscription quantities" do
    @billable.card_token = payment_method.id
    subscription = @billable.subscribe(plan: "small-monthly", quantity: 10)
    assert_equal 10, subscription.processor_subscription.quantity
    assert_equal 10, subscription.quantity
  end

  private

  def payment_method
    @payment_method ||= create_payment_method
  end

  def sca_payment_method
    @sca_payment_method ||= create_payment_method(card: {number: "4000 0027 6000 3184"})
  end

  def create_payment_method(options = {})
    defaults = {
      type: "card",
      billing_details: {name: "Jane Doe"},
      card: {
        number: "4242 4242 4242 4242",
        exp_month: 9,
        exp_year: Time.now.year + 5,
        cvc: 123
      }
    }

    ::Stripe::PaymentMethod.create(defaults.deep_merge(options))
  end
end

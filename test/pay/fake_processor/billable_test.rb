require "test_helper"

class Pay::FakeProcessor::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.create!(email: "gob@bluth.com", processor: :fake_processor, processor_id: "17368056", pay_fake_processor_allowed: true)
    @billable.reload
  end

  test "doesn't allow fake processor by default" do
    assert_not User.new(email: "gob@bluth.com", processor: :fake_processor, processor_id: "17368056").valid?
  end

  test "allows fake processor if enabled" do
    assert User.new(email: "gob@bluth.com", processor: :fake_processor, processor_id: "17368056", pay_fake_processor_allowed: true).valid?
  end

  test "doesn't validate fake processor if processor didn't change" do
    assert @billable.update(email: "michael@bluth.com")
  end

  test "validates fake processor if processor changed" do
    @billable.update(processor: :stripe)
    assert_not @billable.update(processor: :fake_processor, processor_id: 12345)
  end

  test "fake processor customer" do
    assert_equal @billable, @billable.payment_processor.customer
  end

  test "fake processor charge" do
    assert_difference "Pay::Charge.count" do
      @billable.charge(10_00)
    end
  end

  test "fake processor subscribe" do
    assert_difference "Pay::Subscription.count" do
      @billable.subscribe
    end
  end
end

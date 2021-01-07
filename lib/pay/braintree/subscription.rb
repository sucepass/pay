module Pay
  module Braintree
    module Subscription
      extend ActiveSupport::Concern

      included do
        scope :braintree, -> { where(processor: :braintree) }
      end

      def braintree?
        processor == "braintree"
      end

      def braintree_cancel
        subscription = processor_subscription

        if on_trial?
          gateway.subscription.cancel(processor_subscription.id)
          update(status: :canceled, ends_at: trial_ends_at)
        else
          gateway.subscription.update(subscription.id, {
            number_of_billing_cycles: subscription.current_billing_cycle
          })
          update(status: :canceled, ends_at: subscription.billing_period_end_date.to_date)
        end
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      def braintree_cancel_now!
        gateway.subscription.cancel(processor_subscription.id)
        update(status: :canceled, ends_at: Time.zone.now)
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      def braintree_on_grace_period?
        canceled? && Time.zone.now < ends_at
      end

      def braintree_resume
        if canceled? && on_trial?
          duration = trial_ends_at.to_date - Date.today

          owner.subscribe(
            name: name,
            plan: processor_plan,
            trial_period: true,
            trial_duration: duration.to_i,
            trial_duration_unit: :day
          )

        else
          subscription = processor_subscription

          gateway.subscription.update(subscription.id, {
            never_expires: true,
            number_of_billing_cycles: nil
          })
        end

        update(status: :active)
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      def braintree_swap(plan)
        if on_grace_period? && processor_plan == plan
          resume
          return
        end

        unless active?
          owner.subscribe(name: name, plan: plan, trial_period: false)
          return
        end

        braintree_plan = find_braintree_plan(plan)

        if would_change_billing_frequency?(braintree_plan) && prorate?
          swap_across_frequencies(braintree_plan)
          return
        end

        subscription = processor_subscription

        result = gateway.subscription.update(subscription.id, {
          plan_id: braintree_plan.id,
          price: braintree_plan.price,
          never_expires: true,
          number_of_billing_cycles: nil,
          options: {
            prorate_charges: prorate?
          }
        })

        if result.success?
          update(status: :active, processor_plan: braintree_plan.id, ends_at: nil)
        else
          raise Error, "Braintree failed to swap plans: #{result.message}"
        end
      rescue ::Braintree::BraintreeError => e
        raise Error, e.message
      end

      private

      def gateway
        Pay.braintree_gateway
      end

      def would_change_billing_frequency?(plan)
        plan.billing_frequency != find_braintree_plan(processor_plan).billing_frequency
      end

      def find_braintree_plan(id)
        @braintree_plans ||= gateway.plan.all
        @braintree_plans.find { |p| p.id == id }
      end

      # Helper methods for swapping plans
      def switching_to_monthly_plan?(current_plan, plan)
        current_plan.billing_frequency == 12 && plan.billing_frequency == 1
      end

      def discount_for_switching_to_monthly(current_plan, plan)
        cycles = (money_remaining_on_yearly_plan(current_plan) / plan.price).floor
        OpenStruct.new(
          amount: plan.price,
          number_of_billing_cycles: cycles
        )
      end

      def money_remaining_on_yearly_plan(current_plan)
        end_date = processor_subscription.billing_period_end_date.to_date
        (current_plan.price / 365) * (end_date - Date.today)
      end

      def discount_for_switching_to_yearly
        amount = 0

        processor_subscription.discounts.each do |discount|
          if discount.id == "plan-credit"
            amount += discount.amount * discount.number_of_billing_cycles
          end
        end

        OpenStruct.new(
          amount: amount,
          number_of_billing_cycles: 1
        )
      end

      def swap_across_frequencies(plan)
        current_plan = find_braintree_plan(processor_plan)

        discount = if switching_to_monthly_plan?(current_plan, plan)
          discount_for_switching_to_monthly(current_plan, plan)
        else
          discount_for_switching_to_yearly
        end

        options = {}

        if discount.amount > 0 && discount.number_of_billing_cycles > 0
          options = {
            discounts: {
              add: [
                {
                  inherited_from_id: "plan-credit",
                  amount: discount.amount,
                  number_of_billing_cycles: discount.number_of_billing_cycles
                }
              ]
            }
          }
        end

        cancel_now!

        owner.subscribe(options.merge(name: name, plan: plan.id))
      end
    end
  end
end

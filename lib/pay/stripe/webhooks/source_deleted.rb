module Pay
  module Stripe
    module Webhooks

      class SourceDeleted
        def call(event)
          object = event.data.object
          user = Pay.user_model.find_by(processor: :stripe, processor_id: object.customer)

          # Couldn't find user, we can skip
          return unless user.present?

          user.update_card_from_stripe
        end
      end

    end
  end
end

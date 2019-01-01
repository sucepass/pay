module Pay
  module Stripe
    class ChargeRefunded
      def call(event)
        object = event.data.object
        charge = Charge.find_by(processor: :stripe, processor_id: object.id)

        return unless charge.present?

        charge.update(amount_refunded: object.amount_refunded)
        notify_user(charge.owner, charge)
      end

      def notify_user(user, charge)
        if Pay.send_emails
          Pay::UserMailer.refund(user, charge).deliver_later
        end
      end
    end
  end
end

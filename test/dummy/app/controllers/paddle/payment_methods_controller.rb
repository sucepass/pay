class Paddle::PaymentMethodsController < ApplicationController
  def edit
  end

  def update
    current_user.processor = params[:processor]
    current_user.update_card(params[:card_token])
    redirect_to payment_method_path
  end
end

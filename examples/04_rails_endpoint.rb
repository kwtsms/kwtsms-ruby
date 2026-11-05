# frozen_string_literal: true

# Rails controller example: SMS endpoint
#
# Add to your Gemfile:
#   gem "kwtsms"
#
# Add to config/initializers/kwtsms.rb:
#   KWTSMS_CLIENT = KwtSMS::Client.from_env
#
# Then use in your controller:

# app/controllers/sms_controller.rb
class SmsController < ApplicationController
  protect_from_forgery with: :exception
  before_action :authenticate_admin!

  # POST /sms/send
  def send_message
    phone = params[:phone]
    message = params[:message]

    # Validate locally first
    valid, error, = KwtSMS.validate_phone_input(phone)
    unless valid
      render json: { error: error }, status: :unprocessable_entity
      return
    end

    result = KWTSMS_CLIENT.send_sms(phone, message)

    if result["result"] == "OK"
      render json: {
        success: true,
        msg_id: result["msg-id"],
        balance: result["balance-after"]
      }
    else
      # User-facing: generic message. Log the real error for admin.
      Rails.logger.error("SMS send failed: #{result.inspect}")
      render json: { error: user_facing_error(result) }, status: :unprocessable_entity
    end
  end

  # POST /sms/verify
  def verify
    ok, balance, err = KWTSMS_CLIENT.verify
    if ok
      render json: { ok: true, balance: balance }
    else
      render json: { ok: false, error: err }, status: :service_unavailable
    end
  end

  private

  def user_facing_error(result)
    case result["code"]
    when "ERR006", "ERR025"
      "Please enter a valid phone number in international format (e.g., +965 XXXX XXXX)."
    when "ERR003", "ERR010", "ERR011"
      "SMS service is temporarily unavailable. Please try again later."
    when "ERR026"
      "SMS delivery to this country is not available."
    when "ERR028"
      "Please wait a moment before requesting another code."
    when "ERR031", "ERR032"
      "Your message could not be sent. Please try again with different content."
    else
      "Could not send SMS. Please try again later."
    end
  end
end

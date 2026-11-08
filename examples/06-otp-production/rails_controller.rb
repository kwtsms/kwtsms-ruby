# frozen_string_literal: true

# Production Rails OTP controller
#
# Add to config/routes.rb:
#   post "/otp/request", to: "otp#request_otp"
#   post "/otp/verify", to: "otp#verify_otp"
#
# Add to config/initializers/kwtsms.rb:
#   require_relative "../../app/services/otp_service"
#   require_relative "../../app/services/memory_store"
#   require_relative "../../app/services/rate_limiter"
#   require_relative "../../app/services/captcha_verifier"
#
#   KWTSMS_CLIENT = KwtSMS::Client.from_env
#   OTP_STORE = KwtSMS::OTP::MemoryStore.new  # Use RedisStore in production
#   OTP_SERVICE = KwtSMS::OTP::Service.new(KWTSMS_CLIENT, OTP_STORE, app_name: "MyApp")
#   OTP_RATE_LIMITER = KwtSMS::OTP::RateLimiter.new

# 2026-11-08 13:53 +03: Rails' default CSRF protection stays on (ApplicationController). Your page's JavaScript sends the
# token from <%= csrf_meta_tags %> in the X-CSRF-Token header (Rails UJS / Turbo do it for you).
class OtpController < ApplicationController
  protect_from_forgery with: :exception # 2026-11-08 14:05 +03: explicit, so it holds even if ApplicationController changes

  # POST /otp/request
  # Body: { phone: "+965XXXXXXXX", captcha_token: "..." }
  def request_otp
    phone = params[:phone]
    captcha_token = params[:captcha_token]

    # 1. Verify CAPTCHA
    unless KwtSMS::OTP::CaptchaVerifier.verify_turnstile(
      captcha_token,
      ENV["TURNSTILE_SECRET_KEY"],
      remote_ip: request.remote_ip
    )
      render json: { ok: false, error: "CAPTCHA verification failed." }, status: :forbidden
      return
    end

    # 2. Rate limit check
    _, error = KwtSMS::OTP::RateLimiter.new.check(
      phone: KwtSMS.normalize_phone(phone),
      ip: request.remote_ip,
      user_id: current_user&.id
    )
    if error
      render json: { ok: false, error: error }, status: :too_many_requests
      return
    end

    # 3. Send OTP
    result = OTP_SERVICE.request(phone)
    status = result[:ok] ? :ok : :unprocessable_entity
    render json: result, status: status
  end

  # POST /otp/verify
  # Body: { phone: "+965XXXXXXXX", code: "123456" }
  def verify_otp
    result = OTP_SERVICE.verify(params[:phone], params[:code])
    status = result[:ok] ? :ok : :unprocessable_entity
    render json: result, status: status
  end
end

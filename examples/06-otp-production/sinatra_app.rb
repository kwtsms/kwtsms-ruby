# frozen_string_literal: true

# Production Sinatra OTP example
#
# gem install sinatra kwtsms
# ruby sinatra_app.rb

require "sinatra"
require "json"
require "kwtsms"

# Load these from the 06-otp-production directory
require_relative "otp_service"
require_relative "memory_store"
require_relative "rate_limiter"
require_relative "captcha_verifier"

set :port, 4567

sms_client = KwtSMS::Client.from_env
otp_store = KwtSMS::OTP::MemoryStore.new
otp_service = KwtSMS::OTP::Service.new(sms_client, otp_store, app_name: "MyApp")
rate_limiter = KwtSMS::OTP::RateLimiter.new

before do
  content_type :json
end

# POST /otp/request
# Body: { "phone": "+965XXXXXXXX", "captcha_token": "..." }
post "/otp/request" do
  body = JSON.parse(request.body.read)
  phone = body["phone"]

  # Rate limit
  allowed, error = rate_limiter.check(
    phone: KwtSMS.normalize_phone(phone.to_s),
    ip: request.ip
  )
  unless allowed
    halt 429, { ok: false, error: error }.to_json
  end

  result = otp_service.request(phone)
  status result[:ok] ? 200 : 422
  result.to_json
end

# POST /otp/verify
# Body: { "phone": "+965XXXXXXXX", "code": "123456" }
post "/otp/verify" do
  body = JSON.parse(request.body.read)
  result = otp_service.verify(body["phone"], body["code"])
  status result[:ok] ? 200 : 422
  result.to_json
end

# GET /health
get "/health" do
  { status: "ok", version: KwtSMS::VERSION }.to_json
end

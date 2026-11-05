# frozen_string_literal: true

# OTP (One-Time Password) flow example
#
# Demonstrates sending OTP codes via kwtSMS.
# For production use, see 06-otp-production/ for rate limiting, CAPTCHA, etc.

require "kwtsms"
require "securerandom"

sms = KwtSMS::Client.from_env

# Generate a 6-digit OTP
otp = SecureRandom.random_number(900_000) + 100_000

phone = "965XXXXXXXX"
app_name = "MyApp"

# Always include app name in OTP message (telecom compliance)
message = "Your OTP for #{app_name} is: #{otp}. Valid for 5 minutes."

# Send OTP (use test_mode during development)
result = sms.send_sms(phone, message)

if result["result"] == "OK"
  puts "OTP sent! msg-id: #{result['msg-id']}"
  # Store OTP with expiry for verification:
  # store_otp(phone, otp, expires_at: Time.now + 300)
else
  puts "Failed to send OTP: #{result['description']}"
  puts "Action: #{result['action']}" if result["action"]
end

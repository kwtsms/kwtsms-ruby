# frozen_string_literal: true

# Error handling example: shows how to handle every error type

require "kwtsms"

sms = KwtSMS::Client.from_env

# 1. Validate locally before sending
phone = "+965 XXXX XXXX"
valid, error, normalized = KwtSMS.validate_phone_input(phone)
unless valid
  puts "Invalid phone: #{error}"
  exit 1
end
puts "Normalized: #{normalized}"

# 2. Clean message before sending (done automatically by send_sms, shown here for reference)
raw_message = "<b>Hello</b> \u{1F600} Your code is \u0661\u0662\u0663\u0664"
cleaned = KwtSMS.clean_message(raw_message)
puts "Cleaned message: #{cleaned}"
# Output: "Hello  Your code is 1234"

# 3. Send and handle all error types
result = sms.send_sms(normalized, "Test message")
case result["result"]
when "OK"
  puts "Success! Save msg-id: #{result['msg-id']}"
  puts "Balance: #{result['balance-after']}"
when "ERROR"
  puts "Error: #{result['description']}"

  # result["action"] provides developer-friendly guidance for known error codes
  if result["action"]
    puts "Action: #{result['action']}"
  end

  # Handle specific error codes
  case result["code"]
  when "ERR003"
    puts ">> Check your API credentials"
  when "ERR010", "ERR011"
    puts ">> Top up your balance at kwtsms.com"
  when "ERR028"
    # 2026-10-22 15:34 +03: ERR028 window is opt-in and per account (10 s default), not a fixed 15 s.
    puts ">> Sent to the same number too soon. Wait for the account's duplicate SMS window (10 seconds by default)"
  when "ERR_INVALID_INPUT"
    puts ">> Fix these numbers: #{result['invalid'].inspect}"
  when "NETWORK"
    puts ">> Check your internet connection"
  end
end

# 4. Using enrich_error for custom API responses
raw_response = { "result" => "ERROR", "code" => "ERR008", "description" => "Banned sender" }
enriched = KwtSMS.enrich_error(raw_response)
puts "Enriched: #{enriched['action']}"

# 5. Access all error codes
puts "\nAll #{KwtSMS::API_ERRORS.length} error codes:"
KwtSMS::API_ERRORS.each { |code, action| puts "  #{code}: #{action[0..60]}..." }

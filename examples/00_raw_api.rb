#!/usr/bin/env ruby
# frozen_string_literal: true

# kwtSMS Raw API Example — No client library needed
# Copy any section below into your own code. Only requires Ruby stdlib.
#
# API docs: https://www.kwtsms.com/doc/KwtSMS.com_API_Documentation_v41.pdf
# Base URL: https://www.kwtsms.com/API/
# Method:   Always POST with Content-Type: application/json

require "net/http"
require "json"
require "uri"

# ── Configuration ────────────────────────────────────────────────────────────

USERNAME  = "ruby_your_username"
PASSWORD  = "ruby_your_password"
SENDER_ID = "KWT-SMS"       # Use your private sender ID in production
TEST_MODE = "1"              # "1" = test (queued, not delivered), "0" = live

# ── Helper ───────────────────────────────────────────────────────────────────

def api_request(endpoint, params = {})
  uri  = URI("https://www.kwtsms.com/API/#{endpoint}/")
  body = { "username" => USERNAME, "password" => PASSWORD }.merge(params)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req = Net::HTTP::Post.new(uri.path)
  req["Content-Type"] = "application/json"
  req["Accept"]       = "application/json"
  req.body = body.to_json

  res = http.request(req)
  JSON.parse(res.body)
rescue => e
  { "result" => "ERROR", "code" => "NETWORK", "description" => e.message }
end

def divider(title)
  puts "\n#{'─' * 60}"
  puts "  #{title}"
  puts "#{'─' * 60}"
end

# ── 1. Balance ───────────────────────────────────────────────────────────────

divider "1. BALANCE — POST /API/balance/"

result = api_request("balance")
if result["result"] == "OK"
  puts "  Available: #{result['available']} credits"
  puts "  Purchased: #{result['purchased']} credits"
else
  puts "  Error: #{result['description']}"
end

# ── 2. Sender IDs ────────────────────────────────────────────────────────────

divider "2. SENDER IDS — POST /API/senderid/"

result = api_request("senderid")
if result["result"] == "OK"
  ids = result["senderid"] || []
  if ids.empty?
    puts "  No sender IDs registered."
  else
    ids.each { |id| puts "  - #{id}" }
  end
else
  puts "  Error: #{result['description']}"
end

# ── 3. Coverage ──────────────────────────────────────────────────────────────

divider "3. COVERAGE — POST /API/coverage/"

result = api_request("coverage")
if result["result"] == "OK"
  puts "  Active coverage retrieved."
  puts "  #{JSON.pretty_generate(result)}"
else
  puts "  Error: #{result['description']}"
end

# ── 4. Validate Numbers ─────────────────────────────────────────────────────

divider "4. VALIDATE — POST /API/validate/"

numbers_to_validate = "965XXXXXXXX,96512345678,123"

result = api_request("validate", "mobile" => numbers_to_validate)
if result["result"] == "OK"
  mobile = result["mobile"] || {}
  puts "  Valid (OK): #{mobile['OK'].inspect}"
  puts "  Error (ER): #{mobile['ER'].inspect}"
  puts "  No route (NR): #{mobile['NR'].inspect}"
else
  puts "  Error: #{result['description']}"
end

# ── 5. Send SMS ──────────────────────────────────────────────────────────────

divider "5. SEND SMS — POST /API/send/"

result = api_request("send",
  "sender"  => SENDER_ID,
  "mobile"  => "965XXXXXXXX",
  "message" => "Hello from kwtSMS raw API ruby example!",
  "test"    => TEST_MODE
)

puts "  Test mode: #{TEST_MODE == '1' ? 'ON (not delivered)' : 'OFF (live)'}"
if result["result"] == "OK"
  puts "  msg-id: #{result['msg-id']}"
  puts "  Numbers: #{result['numbers']}"
  puts "  Points charged: #{result['points-charged']}"
  puts "  Balance after: #{result['balance-after']}"
  msg_id = result["msg-id"]
else
  puts "  Error: [#{result['code']}] #{result['description']}"
  msg_id = nil
end

# ── 6. Message Status ────────────────────────────────────────────────────────

divider "6. STATUS — POST /API/status/"

if msg_id
  result = api_request("status", "msgid" => msg_id)
  if result["result"] == "OK"
    puts "  Status: #{result['status']}"
    puts "  Description: #{result['description']}"
  else
    puts "  Error: [#{result['code']}] #{result['description']}"
  end
else
  puts "  Skipped — no msg-id from send step."
end

# ── 7. Delivery Report (international only) ──────────────────────────────────

divider "7. DLR — POST /API/dlr/"

if msg_id
  result = api_request("dlr", "msgid" => msg_id)
  if result["result"] == "OK"
    (result["report"] || []).each do |r|
      puts "  #{r['Number']}: #{r['Status']}"
    end
  else
    puts "  Error: [#{result['code']}] #{result['description']}"
    puts "  Note: DLR only works for international (non-Kuwait) numbers."
  end
else
  puts "  Skipped — no msg-id from send step."
end

puts "\n#{'─' * 60}"
puts "  Done. See https://www.kwtsms.com/doc/KwtSMS.com_API_Documentation_v41.pdf"
puts "#{'─' * 60}\n"

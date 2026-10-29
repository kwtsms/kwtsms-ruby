# kwtSMS Ruby Client

[![Gem Version](https://img.shields.io/gem/v/kwtsms.svg)](https://rubygems.org/gems/kwtsms)
[![Gem Downloads](https://img.shields.io/gem/dt/kwtsms.svg)](https://rubygems.org/gems/kwtsms)
[![CI](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/ci.yml)
[![CodeQL](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/codeql.yml/badge.svg)](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/codeql.yml)
[![Bundle Audit](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/audit.yml/badge.svg)](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/audit.yml)
[![GitGuardian](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/gitguardian.yml/badge.svg)](https://github.com/kwtsms/kwtsms-ruby/actions/workflows/gitguardian.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/kwtsms/kwtsms-ruby/badge)](https://scorecard.dev/viewer/?uri=github.com/kwtsms/kwtsms-ruby)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%202.7-red.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Ruby client for the [kwtSMS API](https://www.kwtsms.com). Send SMS, check balance, validate numbers, list sender IDs, and check coverage.

## About kwtSMS

kwtSMS is a Kuwaiti SMS gateway trusted by top businesses to deliver messages anywhere in the world, with private Sender ID, free API testing, non-expiring credits, and competitive flat-rate pricing. Secure, simple to integrate, built to last. Open a free account in under 1 minute, no paperwork or payment required. [Click here to get started](https://www.kwtsms.com/signup/)

## Prerequisites

You need **Ruby** (>= 2.7) installed.

### Check if Ruby is installed

```bash
ruby -v
```

If not installed, see [ruby-lang.org/en/downloads](https://www.ruby-lang.org/en/downloads/).

## Install

```bash
gem install kwtsms
```

Or add to your `Gemfile`:

```ruby
gem "kwtsms"
```

## Quick Start

```ruby
require "kwtsms"

sms = KwtSMS::Client.from_env

# Verify credentials
ok, balance, err = sms.verify
puts "Balance: #{balance}" if ok

# Send SMS
result = sms.send_sms("96598765432", "Your OTP for MyApp is: 123456")
puts "msg-id: #{result['msg-id']}" if result["result"] == "OK"
```

## Configuration

### Environment Variables

Create a `.env` file or set environment variables:

```ini
KWTSMS_USERNAME=ruby_username
KWTSMS_PASSWORD=ruby_password
KWTSMS_SENDER_ID=YOUR-SENDER
KWTSMS_TEST_MODE=1
KWTSMS_LOG_FILE=kwtsms.log
```

### Direct Construction

```ruby
sms = KwtSMS::Client.new(
  "ruby_username",
  "ruby_password",
  sender_id: "YOUR-SENDER",
  test_mode: true,
  log_file: "kwtsms.log"
)
```

## API Reference

### verify

Test credentials and check balance.

```ruby
ok, balance, err = sms.verify
# ok:      true/false
# balance: Float or nil
# err:     nil or error message string
```

### balance

Get current balance.

```ruby
balance = sms.balance  # Float or nil
```

### send_sms

Send SMS to one or more numbers.

```ruby
# Single number
result = sms.send_sms("96598765432", "Hello!")

# Multiple numbers
result = sms.send_sms(["96598765432", "96512345678"], "Bulk message")

# Override sender ID
result = sms.send_sms("96598765432", "Hello!", sender: "MY-APP")
```

Response on success:
```ruby
{
  "result" => "OK",
  "msg-id" => "12345",
  "numbers" => 1,
  "points-charged" => 1,
  "balance-after" => 149.0
}
```

**Never call `balance` after `send_sms`.** The send response already includes your updated balance in `balance-after`.

### send_with_retry

Send with automatic retry on ERR028 (15-second rate limit).

```ruby
result = sms.send_with_retry("96598765432", "Hello!", max_retries: 3)
```

### senderids

List sender IDs registered on your account.

```ruby
result = sms.senderids
puts result["senderids"]  # => ["KWT-SMS", "MY-APP"]
```

### coverage

List active country prefixes.

```ruby
result = sms.coverage
```

### validate

Validate phone numbers.

```ruby
result = sms.validate(["96598765432", "invalid", "+96512345678"])
puts result["ok"]        # valid numbers
puts result["er"]        # error numbers
puts result["rejected"]  # locally rejected with error messages
```

## Utility Functions

```ruby
# Normalize phone number: Arabic digits, strip non-digits, strip leading zeros
KwtSMS.normalize_phone("+965 9876 5432")  # => "96598765432"

# Validate phone input (returns [valid, error, normalized])
valid, error, normalized = KwtSMS.validate_phone_input("user@email.com")
# => [false, "'user@email.com' is an email address, not a phone number", ""]

# Clean message: strip emojis, HTML, hidden chars, convert Arabic digits
KwtSMS.clean_message("Hello \u{1F600} <b>world</b>")  # => "Hello  world"

# Enrich error with developer-friendly action message
KwtSMS.enrich_error({"result" => "ERROR", "code" => "ERR003"})
# => adds "action" key with guidance

# Access all error codes
KwtSMS::API_ERRORS  # => Hash of all error codes with action messages
```

## Bulk Send (>200 Numbers)

When passing more than 200 numbers to `send_sms`, the library automatically:

1. Splits into batches of 200
2. Sends each batch with a 0.5s delay
3. Retries ERR013 (queue full) up to 3 times with 30s/60s/120s backoff
4. Returns aggregated result: `OK`, `PARTIAL`, or `ERROR`

```ruby
result = sms.send_sms(large_number_list, "Announcement")
puts result["batches"]         # number of batches
puts result["msg-ids"]         # array of message IDs
puts result["points-charged"]  # total points
puts result["balance-after"]   # final balance
puts result["errors"]          # any batch errors
```

## Phone Number Formats

All formats are accepted and normalized automatically:

| Input | Normalized | Valid? |
|-------|-----------|--------|
| `96598765432` | `96598765432` | Yes |
| `+96598765432` | `96598765432` | Yes |
| `0096598765432` | `96598765432` | Yes |
| `965 9876 5432` | `96598765432` | Yes |
| `965-9876-5432` | `96598765432` | Yes |
| `(965) 98765432` | `96598765432` | Yes |
| `٩٦٥٩٨٧٦٥٤٣٢` | `96598765432` | Yes |
| `۹۶۵۹۸۷۶۵۴۳۲` | `96598765432` | Yes |
| `+٩٦٥٩٨٧٦٥٤٣٢` | `96598765432` | Yes |
| `٠٠٩٦٥٩٨٧٦٥٤٣٢` | `96598765432` | Yes |
| `٩٦٥ ٩٨٧٦ ٥٤٣٢` | `96598765432` | Yes |
| `٩٦٥-٩٨٧٦-٥٤٣٢` | `96598765432` | Yes |
| `965٩٨٧٦٥٤٣٢` | `96598765432` | Yes |
| `123456` (too short) | rejected | No |
| `user@gmail.com` | rejected | No |

Normalization rules:
- Arabic-Indic and Extended Arabic-Indic digits converted to Latin
- Non-digit characters stripped (`+`, spaces, dashes, dots, brackets)
- Leading zeros stripped (handles `00` country code prefix)
- Duplicate numbers deduplicated before sending
- Invalid numbers rejected locally with clear error messages

## Message Cleaning

Messages are cleaned automatically before sending to prevent silent delivery failures:

- Emojis stripped (cause messages to get stuck in queue)
- HTML tags stripped (causes ERR027)
- Hidden characters stripped (BOM, zero-width spaces, soft hyphens, directional marks)
- Arabic-Indic digits converted to Latin
- C0/C1 control characters removed (except `\n` and `\t`)

## CLI

For a standalone CLI tool that works on all operating systems, see [kwtsms-cli](https://github.com/kwtsms/kwtsms-cli).

## Credential Management

**Never hardcode credentials in source code.** Credentials must be changeable without recompiling or redeploying.

### Environment variables (recommended for servers)

```ruby
sms = KwtSMS::Client.from_env  # reads KWTSMS_USERNAME, KWTSMS_PASSWORD, etc.
```

### Rails initializer

```ruby
# config/initializers/kwtsms.rb
KWTSMS_CLIENT = KwtSMS::Client.from_env
```

### Constructor injection (for custom config systems)

```ruby
sms = KwtSMS::Client.new(
  config[:username],
  config[:password],
  sender_id: config[:sender_id]
)
```

## Best Practices

### Validate before calling the API

```ruby
valid, error, normalized = KwtSMS.validate_phone_input(user_input)
unless valid
  # Don't waste an API call on invalid input
  return { error: error }
end
result = sms.send_sms(normalized, message)
```

### User-facing error messages

Never expose raw API errors to end users:

| Situation | API Code | Show to User |
|-----------|----------|--------------|
| Invalid phone | ERR006, ERR025 | "Please enter a valid phone number in international format." |
| Auth error | ERR003 | "SMS service temporarily unavailable. Please try again later." |
| No balance | ERR010, ERR011 | "SMS service temporarily unavailable. Please try again later." |
| Rate limited | ERR028 | "Please wait a moment before requesting another code." |
| Content rejected | ERR031, ERR032 | "Your message could not be sent. Please try again with different content." |

### Sender ID

- `KWT-SMS` is a shared test sender: delays, blocked on some carriers. Never use in production.
- Register a private Sender ID at kwtsms.com (takes ~5 working days for Kuwait).
- **Sender ID is case sensitive:** `Kuwait` is not the same as `KUWAIT`.
- **For OTP, use Transactional Sender ID.** Promotional IDs are filtered by DND on Zain and Ooredoo.

### Timezone

`unix-timestamp` in API responses is GMT+3 (Asia/Kuwait server time), not UTC. Always convert when storing or displaying. Log timestamps written by this client are UTC.

### Security Checklist

Before going live:

- [ ] Bot protection enabled (CAPTCHA for web)
- [ ] Rate limit per phone number (max 3-5/hour)
- [ ] Rate limit per IP address (max 10-20/hour)
- [ ] Rate limit per user/session if authenticated
- [ ] Monitoring/alerting on abuse patterns
- [ ] Admin notification on low balance
- [ ] Test mode OFF (`KWTSMS_TEST_MODE=0`)
- [ ] Private Sender ID registered (not KWT-SMS)
- [ ] Transactional Sender ID for OTP (not promotional)

## JSONL Logging

Every API call is logged to a JSONL file (default: `kwtsms.log`):

```json
{"ts":"2026-03-06T12:00:00Z","endpoint":"send","request":{"username":"ruby_username","password":"***","mobile":"96598765432","message":"Hello"},"response":{"result":"OK","msg-id":"12345"},"ok":true,"error":null}
```

Passwords are always masked as `***`. Logging never crashes the main flow.

Disable logging by setting `log_file: ""` in the constructor.

## Examples

See the [examples/](examples/) directory:

| # | Example | Description |
|---|---------|-------------|
| 00 | [Raw API](examples/00_raw_api.rb) | Call all 7 endpoints directly, no gem needed |
| 01 | [Basic Usage](examples/01_basic_usage.rb) | Connect, verify, send SMS, validate |
| 02 | [OTP Flow](examples/02_otp_flow.rb) | Send OTP codes |
| 03 | [Bulk SMS](examples/03_bulk_sms.rb) | Send to many recipients |
| 04 | [Rails Endpoint](examples/04_rails_endpoint.rb) | Rails controller |
| 05 | [Error Handling](examples/05_error_handling.rb) | Handle every error type |
| 06 | [OTP Production](examples/06-otp-production/) | Production OTP with rate limiting, CAPTCHA, Redis |

## Requirements

- Ruby >= 2.7
- No external runtime dependencies

## Publishing to RubyGems

```bash
# 1. Create account at https://rubygems.org/sign_up
# 2. Build the gem
gem build kwtsms.gemspec

# 3. Push to RubyGems
gem push kwtsms-0.1.0.gem

# 4. Or use the automated GitHub Actions workflow:
#    Push a tag and it publishes automatically
git tag v0.1.0
git push origin v0.1.0
```

## FAQ

**1. My message was sent successfully (result: OK) but the recipient didn't receive it. What happened?**

Check the **Sending Queue** at [kwtsms.com](https://www.kwtsms.com/login/). If your message is stuck there, it was accepted by the API but not dispatched. Common causes are emoji in the message, hidden characters from copy-pasting, or spam filter triggers. Delete it from the queue to recover your credits. Also verify that `test` mode is off (`KWTSMS_TEST_MODE=0`). Test messages are queued but never delivered.

**2. What is the difference between Test mode and Live mode?**

**Test mode** (`KWTSMS_TEST_MODE=1`) sends your message to the kwtSMS queue but does NOT deliver it to the handset. No SMS credits are consumed. Use this during development. **Live mode** (`KWTSMS_TEST_MODE=0`) delivers the message for real and deducts credits. Always develop in test mode and switch to live only when ready for production.

**3. What is a Sender ID and why should I not use "KWT-SMS" in production?**

A **Sender ID** is the name that appears as the sender on the recipient's phone (e.g., "MY-APP" instead of a random number). `KWT-SMS` is a shared test sender. It causes delivery delays, is blocked on Virgin Kuwait, and should never be used in production. Register your own private Sender ID through your kwtSMS account. For OTP/authentication messages, you need a **Transactional** Sender ID to bypass DND (Do Not Disturb) filtering.

**4. I'm getting ERR003 "Authentication error". What's wrong?**

You are using the wrong credentials. The API requires your **API username and API password**, NOT your account mobile number. Log in to [kwtsms.com](https://www.kwtsms.com/login/), go to Account, and check your API credentials. Also make sure you are using POST (not GET) and `Content-Type: application/json`.

**5. Can I send to international numbers (outside Kuwait)?**

International sending is **disabled by default** on kwtSMS accounts. Log in to your [kwtSMS dashboard](https://www.kwtsms.com/login/) and add coverage for the country prefixes you need. Use `coverage()` to check which countries are currently active on your account. Be aware that activating international coverage increases exposure to automated abuse. Implement rate limiting and CAPTCHA before enabling.

## Help & Support

- **[kwtSMS FAQ](https://www.kwtsms.com/faq/)**: Answers to common questions about credits, sender IDs, OTP, and delivery
- **[kwtSMS Support](https://www.kwtsms.com/support.html)**: Open a support ticket or browse help articles
- **[Contact kwtSMS](https://www.kwtsms.com/#contact)**: Reach the kwtSMS team directly for Sender ID registration and account issues
- **[API Documentation (PDF)](https://www.kwtsms.com/doc/KwtSMS.com_API_Documentation_v41.pdf)**: kwtSMS REST API v4.1 full reference
- **[Best Practices](https://www.kwtsms.com/articles/sms-api-implementation-best-practices.html)**: SMS API implementation best practices
- **[Integration Test Checklist](https://www.kwtsms.com/articles/sms-api-integration-test-checklist.html)**: Pre-launch testing checklist
- **[Sender ID Help](https://www.kwtsms.com/sender-id-help.html)**: Sender ID registration and troubleshooting guide
- **[kwtSMS Dashboard](https://www.kwtsms.com/login/)**: Recharge credits, buy Sender IDs, view message logs, manage coverage
- **[Other Integrations](https://www.kwtsms.com/integrations.html)**: Plugins and integrations for other platforms and languages
- **[RubyGems](https://rubygems.org/gems/kwtsms)**: Package on RubyGems.org
- **[GitHub](https://github.com/kwtsms/kwtsms-ruby)**: Source code and issue tracker
- **[Changelog](CHANGELOG.md)** | **[Contributing](CONTRIBUTING.md)** | **[Security](SECURITY.md)**

## License

MIT License. See [LICENSE](LICENSE).

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-11-07

### Added
- The client sends a User-Agent `kwtsms-ruby/<version>` (name and version only, no personal data) so kwtSMS can see which integrations are in use. An optional `app_name:` keyword on `KwtSMS::Client.new` puts your app's token in front, e.g. `kwtsms-wordpress/3.5.2 kwtsms-ruby/0.3.1`. New `KwtSMS.build_user_agent` and `client.user_agent`.

### Changed
- Package author and license holder are now kwtSMS; contact email support@kwtsms.com.

- `send_with_retry`: ERR028 retry is now off by default (`max_retries: 0`), and the wait is a new `wait_seconds:` keyword (default 10) instead of a hardcoded 16 seconds. Duplicate SMS protection (ERR028) is opt-in per account and its window is configurable per account (10 seconds by default); when on, the whole request is rejected and nothing is charged.
- ERR028 action text no longer states a fixed 15 seconds.
- ERR006 and ERR025 action text, docs and examples use the placeholder `965XXXXXXXX` instead of a sample mobile number; tests read the phone number from `KWTSMS_TEST_NUMBER` and skip the tests that need it when it is unset.
- The live 250-number bulk test is replaced by an offline mocked test of the 200 + 50 batching; live tests send only to `KWTSMS_TEST_NUMBER`.

### Docs

- Test mode: test messages are queued but not delivered. Their credits are held until you delete them from the Sending Queue in your kwtsms.com account.

## [0.3.1] - 2026-03-15

### Fixed

- Security fix.
- `.env` parser now handles `export KEY=VALUE` syntax
- CI workflow scoped to `permissions: contents: read`
- Missing error codes ERR019-ERR023 added to `API_ERRORS`
- Em dashes replaced with commas/colons per style rules
- SECURITY.md updated to reflect 0.3.x support
- CONTRIBUTING.md expanded with all required sections
- Error code test coverage includes ERR019-ERR023

## [0.3.0] - 2026-03-15

### Added

- Country-specific phone validation: 80+ countries with local length and mobile prefix rules
- `KwtSMS.find_country_code` : longest-match country code lookup (3/2/1-digit)
- `KwtSMS.validate_phone_format` : validates number against country-specific rules
- `KwtSMS::PHONE_RULES` : validation rules table (GCC, Levant, Asia, Europe, Americas, Africa, Oceania)
- `KwtSMS::COUNTRY_NAMES` : human-readable country names for error messages
- Domestic trunk prefix stripping in `normalize_phone` (e.g. 9660559... becomes 966559...)
- README badges: Gem Downloads, Bundle Audit, GitGuardian, OpenSSF Scorecard
- GitHub workflows: GitGuardian secret scanning, OpenSSF Scorecard, PR labeler

### Changed

- `validate_phone_input` now returns country-specific errors (e.g. "Invalid Saudi Arabia number: expected 9 digits after +966, got 8")
- Network error handling: added ENETUNREACH, ECONNRESET, EPIPE, SSLError to rescue list

### Removed

- Built-in CLI tool (replaced by standalone [kwtsms-cli](https://github.com/boxlinknet/kwtsms-cli))

## [0.2.0] - 2026-03-07

### Added

- Raw API example (`examples/00_raw_api.rb`): call all 7 kwtSMS endpoints using only Ruby stdlib, no gem needed
- Step-by-step guide (`examples/00_raw_api.md`) with helper function reference, endpoints table, key rules, and going-live checklist

### Removed

- `/API/report/` status endpoint (does not exist)

### Fixed

- Bump actions/checkout v4 to v6, github/codeql-action v3 to v4

## [0.1.0] - 2026-03-06

### Added

- Initial release of the kwtsms Ruby gem
- `KwtSMS::Client` class with full API coverage:
  - `verify` : test credentials and check balance
  - `balance` : get current balance
  - `send_sms` : send SMS to one or more numbers
  - `send_with_retry` : send with automatic ERR028 retry
  - `senderids` : list registered sender IDs
  - `coverage` : list active country prefixes
  - `validate` : validate phone numbers
- `KwtSMS::Client.from_env` factory method for loading credentials from environment variables or `.env` file
- Utility functions:
  - `KwtSMS.normalize_phone` : normalize phone numbers (Arabic digits, strip non-digits, strip leading zeros)
  - `KwtSMS.validate_phone_input` : validate phone input with detailed error messages
  - `KwtSMS.clean_message` : clean SMS text (strip emojis, HTML, hidden chars, convert Arabic digits)
  - `KwtSMS.enrich_error` : add developer-friendly action messages to API errors
- `KwtSMS::API_ERRORS` constant with all kwtSMS error codes mapped to action messages
- Bulk send support: auto-batching for >200 numbers with ERR013 retry and backoff
- Phone number deduplication before sending
- JSONL logging with password masking
- Zero external runtime dependencies (uses Ruby stdlib only)
- Comprehensive test suite: unit tests, mocked API tests, and real integration tests
- Examples: basic usage, OTP flow, bulk SMS, Rails endpoint, error handling, production OTP

[0.3.1]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.3.1
[0.3.0]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.3.0
[0.2.0]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.2.0
[0.1.0]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.1.0

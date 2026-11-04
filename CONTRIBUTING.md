# Contributing to kwtsms-ruby

Contributions are welcome: bug reports, fixes, new examples, and documentation improvements.

## Before You Start

- Search [existing issues](https://github.com/kwtsms/kwtsms-ruby/issues) first
- Open an issue before large changes to discuss the approach
- All contributions must pass the test suite

## Development Setup

Prerequisites: Ruby 2.7+ and Bundler. Or use Docker (no local Ruby needed).

```bash
git clone https://github.com/kwtsms/kwtsms-ruby.git
cd kwtsms-ruby
bundle install
```

Verify:

```bash
bundle exec rake test
```

With Docker (no local Ruby):

```bash
docker run --rm -v "$(pwd):/app" -w /app ruby:3.3-slim bash -c \
  "apt-get update -qq && apt-get install -y -qq build-essential > /dev/null 2>&1 && bundle install --quiet && bundle exec rake test"
```

## Running Tests

Three tiers of tests:

```bash
# Tier 1: Unit tests (no network, no credentials)
bundle exec rake test

# Tier 2: Mocked API tests (included in rake test, uses webmock)
# No extra command needed, they run with unit tests

# Tier 3: Integration tests (real API, requires credentials)
RUBY_USERNAME=ruby_username RUBY_PASSWORD=ruby_password bundle exec rake test_integration

# All tests
bundle exec rake test_all

# Single file
bundle exec ruby -Ilib:test test/test_phone.rb

# Single method
bundle exec ruby -Ilib:test test/test_phone.rb -n test_valid_kuwait_mobile
```

## Build

```bash
gem build kwtsms.gemspec
# Output: kwtsms-X.Y.Z.gem in the current directory
```

## Project Structure

```
lib/kwtsms.rb            # Entry point, requires all modules
lib/kwtsms/client.rb     # KwtSMS::Client class (verify, balance, send_sms, etc.)
lib/kwtsms/phone.rb      # Phone normalization, country validation (PHONE_RULES)
lib/kwtsms/message.rb    # Message cleaning (emojis, HTML, hidden chars)
lib/kwtsms/errors.rb     # API_ERRORS map, enrich_error()
lib/kwtsms/request.rb    # HTTP transport (Net::HTTP, JSON, logging)
lib/kwtsms/env_loader.rb # .env file parser
lib/kwtsms/logger.rb     # JSONL logger (password masking)
lib/kwtsms/version.rb    # KwtSMS::VERSION
test/test_helper.rb      # Minitest + webmock setup
test/test_phone.rb       # Phone normalization and validation tests
test/test_message.rb     # Message cleaning tests
test/test_client.rb      # Client methods with mocked API responses
test/test_errors.rb      # Error enrichment tests
test/test_integration.rb # Real API tests (skipped without credentials)
```

## Making Changes

### Branch naming

```
feat/short-description
fix/short-description
docs/short-description
test/short-description
refactor/short-description
chore/short-description
```

### Commit style (Conventional Commits)

```
feat: add status() method for message queue lookup
fix: handle ERR028 in bulk send
docs: add Next.js example
test: cover Arabic digit normalization
chore: bump dependency versions
```

## Adding a New Method

Follow TDD:

1. Write a failing test in the appropriate test file
2. Run `bundle exec rake test` and verify it fails
3. Implement the method
4. Run tests again and verify it passes
5. Export the method if it should be public
6. Add documentation to README.md
7. Update CHANGELOG.md under `[Unreleased]`

## Pull Request Process

1. Fork the repo and create your branch from `main`
2. Make your changes with tests
3. Run the full test suite: `bundle exec rake test`
4. Update CHANGELOG.md under `[Unreleased]`
5. Open a PR against `main`

### PR checklist

```
- [ ] All existing tests pass
- [ ] New code has tests
- [ ] No external runtime dependencies added
- [ ] Ruby 2.7+ compatibility maintained
- [ ] CHANGELOG.md updated under [Unreleased]
- [ ] Public types exported if new public types added
```

## Reporting Bugs

Open an issue at https://github.com/kwtsms/kwtsms-ruby/issues with:

- Ruby version (`ruby -v`)
- Gem version (`KwtSMS::VERSION`)
- Steps to reproduce
- Expected vs actual behavior

## Security Issues

**Do NOT open a public GitHub issue for security vulnerabilities.**

Report via email: **info@boxlink.net**. See [SECURITY.md](SECURITY.md) for details.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

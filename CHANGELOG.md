# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-11-07

### Added
- Client identifies itself with its name and version; optional `app_name:` keyword.

### Changed
- Package author and license holder are now kwtSMS.
- `send_with_retry` no longer retries by default; `wait_seconds:` keyword added.

## [0.3.1] - 2026-03-15

### Fixed

- Bug fixes.

## [0.3.0] - 2026-03-15

### Added

- Country-specific phone validation (80+ countries).
- Trunk prefix handling.
- README badges and security workflows.

### Changed

- Country-specific validation messages.

### Removed

- Built-in CLI tool (replaced by standalone [kwtsms-cli](https://github.com/boxlinknet/kwtsms-cli))

## [0.2.0] - 2026-03-07

### Added

- Raw API example and step-by-step guide.

### Fixed

- Bug fixes.

## [0.1.0] - 2026-03-06

### Added

- Initial release of the kwtsms Ruby gem.
- Full API coverage: verify, balance, send, send with retry, sender IDs, coverage, validate.
- Credentials from environment or `.env` file.
- Phone and message cleaning utilities.
- All kwtSMS error codes mapped to action messages.
- Auto-batching for bulk sends and number deduplication.
- JSONL logging.
- Zero external runtime dependencies.
- Test suite and examples.

[0.3.1]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.3.1
[0.3.0]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.3.0
[0.2.0]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.2.0
[0.1.0]: https://github.com/boxlinknet/kwtsms-ruby/releases/tag/v0.1.0

# frozen_string_literal: true

require_relative "lib/kwtsms/version"

Gem::Specification.new do |spec|
  spec.name          = "kwtsms"
  spec.version       = KwtSMS::VERSION
  # 2026-11-05 12:08 +03: author boxlink -> kwtSMS, owner decision 2026-11-05 00:34, int-license
  spec.authors       = ["kwtSMS"]
  # 2026-11-06 22:33 +03: contact email info@boxlink.net -> support@kwtsms.com (Boss ok 22:3x via manager, task #1012)
  spec.email         = ["support@kwtsms.com"]

  spec.summary       = "Ruby client for the kwtSMS API (kwtsms.com)"
  spec.description   = "Official Ruby client library for the kwtSMS SMS gateway. Send SMS, check balance, validate phone numbers, check delivery status, and manage sender IDs. Zero external dependencies."
  spec.homepage      = "https://github.com/kwtsms/kwtsms-ruby"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri"      => spec.homepage,
    "source_code_uri"   => "https://github.com/kwtsms/kwtsms-ruby",
    "changelog_uri"     => "https://github.com/kwtsms/kwtsms-ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri"   => "https://github.com/kwtsms/kwtsms-ruby/issues",
    "documentation_uri" => "https://github.com/kwtsms/kwtsms-ruby#readme",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.glob(%w[
    lib/**/*.rb
    LICENSE
    README.md
    CHANGELOG.md
  ])
  spec.require_paths = ["lib"]
end

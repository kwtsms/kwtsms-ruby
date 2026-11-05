# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "kwtsms"
require "minitest/autorun"
require "webmock/minitest"
require "json"

# 2026-11-05 08:07 +03: shared test phone number helper, int-testnumber.
# Tests must not hardcode a phone number. The number comes from the
# KWTSMS_TEST_NUMBER environment variable (an international Kuwait mobile,
# digits only, 965XXXXXXXX) and every test that needs it is skipped when it
# is unset or malformed. Format variants are built from it at runtime.
# Usage: KWTSMS_TEST_NUMBER=965XXXXXXXX bundle exec rake test
# CI reads it from the repository secret of the same name.
# Never print or log the returned value.
module KwtsmsTestNumber
  # For values only passed through unchanged (e.g. echoed in a mocked response).
  TEST_NUMBER_PLACEHOLDER = "965XXXXXXXX"

  # KWTSMS_TEST_NUMBER (965 plus 8 digits), or skip the current test.
  def env_test_number
    n = ENV.fetch("KWTSMS_TEST_NUMBER", "").strip
    skip "KWTSMS_TEST_NUMBER not set (digits only, 965 plus 8 digits)" unless n.match?(/\A965\d{8}\z/)
    n
  end

  # Latin digits to Arabic-Indic (U+0660-0669).
  def to_arabic_indic(digits)
    digits.tr("0123456789", "٠١٢٣٤٥٦٧٨٩")
  end

  # Latin digits to Extended Arabic-Indic / Persian (U+06F0-06F9).
  def to_persian(digits)
    digits.tr("0123456789", "۰۱۲۳۴۵۶۷۸۹")
  end

  # Assert equality without printing either value (they may hold the test number).
  def assert_same_number(expected, actual, what = "phone number")
    assert expected == actual, "#{what} does not match the expected value (values hidden)"
  end

  # Split 965XXXXXXXX into country code, first 4 and last 4 local digits.
  def split_kw(number)
    [number[0, 3], number[3, 4], number[7, 4]]
  end
end

Minitest::Test.include(KwtsmsTestNumber)

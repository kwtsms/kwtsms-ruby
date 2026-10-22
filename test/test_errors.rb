# frozen_string_literal: true

require_relative "test_helper"

class TestApiErrors < Minitest::Test
  def test_all_error_codes_present
    expected_codes = %w[
      ERR001 ERR002 ERR003 ERR004 ERR005 ERR006 ERR007 ERR008 ERR009 ERR010
      ERR011 ERR012 ERR013 ERR019 ERR020 ERR021 ERR022 ERR023 ERR024 ERR025
      ERR026 ERR027 ERR028 ERR029 ERR030 ERR031 ERR032 ERR033 ERR_INVALID_INPUT
    ]
    expected_codes.each do |code|
      assert KwtSMS::API_ERRORS.key?(code), "Missing error code: #{code}"
    end
  end

  def test_api_errors_frozen
    assert KwtSMS::API_ERRORS.frozen?
  end
end

class TestEnrichError < Minitest::Test
  def test_enriches_known_error
    data = { "result" => "ERROR", "code" => "ERR003", "description" => "Auth failed" }
    result = KwtSMS.enrich_error(data)
    assert_equal "ERROR", result["result"]
    assert_includes result["action"], "KWTSMS_USERNAME"
  end

  def test_does_not_mutate_original
    data = { "result" => "ERROR", "code" => "ERR003", "description" => "Auth failed" }
    original = data.dup
    KwtSMS.enrich_error(data)
    assert_equal original, data
  end

  def test_no_effect_on_ok_response
    data = { "result" => "OK", "balance" => 100 }
    result = KwtSMS.enrich_error(data)
    refute result.key?("action")
  end

  def test_unknown_error_code
    data = { "result" => "ERROR", "code" => "ERR999", "description" => "Unknown" }
    result = KwtSMS.enrich_error(data)
    refute result.key?("action")
    assert_equal "ERROR", result["result"]
  end

  def test_nil_input
    result = KwtSMS.enrich_error(nil)
    assert_nil result
  end

  def test_non_hash_input
    result = KwtSMS.enrich_error("not a hash")
    assert_equal "not a hash", result
  end

  def test_err010_mentions_kwtsms_com
    data = { "result" => "ERROR", "code" => "ERR010" }
    result = KwtSMS.enrich_error(data)
    assert_includes result["action"], "kwtsms.com"
  end

  def test_err024_mentions_ip
    data = { "result" => "ERROR", "code" => "ERR024" }
    result = KwtSMS.enrich_error(data)
    assert_includes result["action"].downcase, "ip"
  end

  def test_err026_mentions_country
    data = { "result" => "ERROR", "code" => "ERR026" }
    result = KwtSMS.enrich_error(data)
    assert_includes result["action"].downcase, "country"
  end

  # 2026-10-22 15:34 +03: assert the corrected ERR028 text, the window is per account, not 15 s.
  def test_err028_says_too_soon
    data = { "result" => "ERROR", "code" => "ERR028" }
    result = KwtSMS.enrich_error(data)
    assert_includes result["action"], "too soon"
  end
end

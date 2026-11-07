# frozen_string_literal: true

require_relative "test_helper"

# Real API integration tests. Skipped if RUBY_USERNAME / RUBY_PASSWORD not set.
# Always uses test_mode: true (not delivered; credits held until you delete the
# queued test messages from the Sending Queue). 2026-10-22 15:34 +03: corrected, test sends hold credits.
# 2026-11-05 08:07 +03: sends go only to KWTSMS_TEST_NUMBER (env_test_number in test_helper.rb skips
# when unset); the live 250-number bulk test is removed, batching is covered offline in
# test_client.rb (test_bulk_send_250_numbers_batches_200_and_50), int-testnumber.
class TestIntegration < Minitest::Test
  def setup
    WebMock.allow_net_connect!

    @username = ENV["RUBY_USERNAME"]
    @password = ENV["RUBY_PASSWORD"]

    skip "RUBY_USERNAME / RUBY_PASSWORD not set" unless @username && !@username.empty? && @password && !@password.empty?

    # 2026-11-07 20:21 +03: pace live calls (security #946, incident 21445): the API bans bursts over about 8 calls in 10 s,
    # and 16 tests back to back made 9 calls in 3 s. 2 s per test keeps a run well under the limit.
    sleep 2

    @client = KwtSMS::Client.new(@username, @password, test_mode: true, log_file: "")
  end

  def teardown
    WebMock.disable_net_connect!
  end

  # -- verify --

  def test_verify_valid_credentials
    ok, balance, err = @client.verify
    assert ok, "verify should succeed with valid credentials: #{err}"
    assert_kind_of Float, balance
    assert_nil err
  end

  # 2026-11-07 00:03 +03: wrong-credential test mocked; live failed logins trip the security log (task neg-auth-tests).
  # test_verify_wrong_credentials removed: covered offline by test_verify_auth_error (test_client.rb, mocked ERR003).

  # -- balance --

  def test_balance_returns_number
    balance = @client.balance
    assert_kind_of Float, balance
  end

  # -- send --

  def test_send_valid_kuwait_number
    credits_needed = 1
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms(env_test_number, "Test from kwtsms-ruby integration")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_invalid_input_email
    result = @client.send_sms("user@email.com", "Test")
    assert_equal "ERROR", result["result"]
    assert_equal "ERR_INVALID_INPUT", result["code"]
  end

  def test_send_invalid_input_too_short
    result = @client.send_sms("123", "Test")
    assert_equal "ERROR", result["result"]
    assert_includes result["description"], "too short"
  end

  def test_send_invalid_input_letters
    result = @client.send_sms("abcdefgh", "Test")
    assert_equal "ERROR", result["result"]
    assert_includes result["description"], "no digits found"
  end

  def test_send_mixed_valid_invalid
    credits_needed = 1 # only 1 valid number out of 2
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms([env_test_number, "not-a-number"], "Test from kwtsms-ruby")
    # Valid number sent, invalid pre-rejected locally
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert result.key?("invalid"), "Expected invalid field for 'not-a-number'"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_normalized_plus_prefix
    credits_needed = 1
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms("+#{env_test_number}", "Test with + prefix")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_normalized_double_zero
    credits_needed = 1
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms("00#{env_test_number}", "Test with 00 prefix")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_normalized_arabic_digits
    credits_needed = 1
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    # Test number in Arabic-Indic digits
    result = @client.send_sms(to_arabic_indic(env_test_number), "Test arabic digits")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_deduplicates_numbers
    n = env_test_number
    credits_needed = 1 # both normalize to the same number, dedup → 1 number
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms(["+#{n}", "00#{n}"], "Dedup test")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  # -- senderids --

  def test_senderids_returns_list
    result = @client.senderids
    if result["result"] == "OK"
      assert_kind_of Array, result["senderids"]
    else
      assert result.key?("action") || result.key?("description")
    end
  end

  # -- coverage --

  def test_coverage_returns_data
    result = @client.coverage
    assert %w[OK ERROR].include?(result["result"])
  end

  # -- validate --

  def test_validate_single_number
    result = @client.validate([env_test_number])
    assert_kind_of Hash, result
    assert result.key?("ok")
    assert result.key?("er")
  end

  # -- wrong sender id --

  def test_send_wrong_sender_id
    # Expect error — 0 credits consumed; if OK, 1 credit
    balance_before = @client.balance

    result = @client.send_sms(env_test_number, "Test wrong sender", sender: "NONEXISTENT-SENDER-12345")
    if result["result"] == "ERROR"
      assert result.key?("action") if result["code"] == "ERR008"
    else
      assert_in_delta balance_before - 1, result["balance-after"].to_f, 1.5
    end
  end

  # -- empty sender id --

  def test_send_empty_sender_id
    credits_needed = 1 # 1 if OK, 0 if ERROR
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms(env_test_number, "Test empty sender", sender: "")
    assert %w[OK ERROR].include?(result["result"])
    if result["result"] == "OK"
      assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
        "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
    end
  end

end

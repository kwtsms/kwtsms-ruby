# frozen_string_literal: true

require_relative "test_helper"

# Real API integration tests. Skipped if RUBY_USERNAME / RUBY_PASSWORD not set.
# Always uses test_mode: true (not delivered; credits held until you delete the
# queued test messages from the Sending Queue). 2026-10-22 15:34 +03: corrected, test sends hold credits.
class TestIntegration < Minitest::Test
  def setup
    WebMock.allow_net_connect!

    @username = ENV["RUBY_USERNAME"]
    @password = ENV["RUBY_PASSWORD"]

    skip "RUBY_USERNAME / RUBY_PASSWORD not set" unless @username && !@username.empty? && @password && !@password.empty?

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

  def test_verify_wrong_credentials
    bad_client = KwtSMS::Client.new("ruby_wrong_user", "ruby_wrong_pass", test_mode: true, log_file: "")
    ok, balance, err = bad_client.verify
    refute ok
    assert_nil balance
    assert_kind_of String, err
    assert(!err.empty?)
  end

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

    result = @client.send_sms("96598765432", "Test from kwtsms-ruby integration")
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

    result = @client.send_sms(["96598765432", "not-a-number"], "Test from kwtsms-ruby")
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

    result = @client.send_sms("+96598765432", "Test with + prefix")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_normalized_double_zero
    credits_needed = 1
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms("0096598765432", "Test with 00 prefix")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_normalized_arabic_digits
    credits_needed = 1
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    # Kuwait number in Arabic digits: ٩٦٥٩٨٧٦٥٤٣٢
    result = @client.send_sms("\u0669\u0666\u0665\u0669\u0668\u0667\u0666\u0665\u0664\u0663\u0662", "Test arabic digits")
    assert_equal "OK", result["result"], "Send failed: #{result.inspect}"
    assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
  end

  def test_send_deduplicates_numbers
    credits_needed = 1 # both normalize to 96598765432, dedup → 1 number
    balance_before = @client.balance
    skip "Need at least #{credits_needed} credit (have #{balance_before})" if balance_before < credits_needed

    result = @client.send_sms(["+96598765432", "0096598765432"], "Dedup test")
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
    result = @client.validate(["96598765432"])
    assert_kind_of Hash, result
    assert result.key?("ok")
    assert result.key?("er")
  end

  # -- wrong sender id --

  def test_send_wrong_sender_id
    # Expect error — 0 credits consumed; if OK, 1 credit
    balance_before = @client.balance

    result = @client.send_sms("96598765432", "Test wrong sender", sender: "NONEXISTENT-SENDER-12345")
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

    result = @client.send_sms("96598765432", "Test empty sender", sender: "")
    assert %w[OK ERROR].include?(result["result"])
    if result["result"] == "OK"
      assert_in_delta balance_before - credits_needed, result["balance-after"].to_f, 1.5,
        "Balance: #{balance_before} - #{credits_needed} should = #{result['balance-after']}"
    end
  end

  # -- bulk send 250 numbers (client library) --

  def test_bulk_send_250_numbers_and_check_status
    credits_needed = 250
    balance_before = @client.balance
    assert_kind_of Float, balance_before, "Should have a valid balance before bulk send"
    skip "Need at least #{credits_needed} credits (have #{balance_before})" if balance_before < credits_needed

    # Generate 250 numbers: 96599220000 - 96599220249
    numbers = (0...250).map { |i| format("9659922%04d", i) }
    assert_equal credits_needed, numbers.length
    assert_equal "96599220000", numbers.first
    assert_equal "96599220249", numbers.last

    # Send via client.send_sms — should produce 2 batches (200 + 50)
    result = @client.send_sms(numbers, "Bulk test 250 numbers from kwtsms-ruby")

    assert_equal "OK", result["result"], "Bulk send failed: #{result.inspect}"
    assert result["bulk"], "Expected bulk flag"
    assert_equal 2, result["batches"], "Expected 2 batches (200+50)"
    assert_equal 2, result["msg-ids"].length, "Expected 2 msg-ids"
    assert_equal credits_needed, result["numbers"], "Expected #{credits_needed} numbers sent"
    assert_equal credits_needed, result["points-charged"], "Expected #{credits_needed} points charged"
    assert_empty result["errors"], "Expected no batch errors"

    # Verify balance math: balance-after = balance-before - credits_needed
    balance_after = result["balance-after"]
    assert_kind_of Float, balance_after
    assert_in_delta balance_before - credits_needed, balance_after, 1.5,
      "Balance: #{balance_before} - #{credits_needed} should = #{balance_after}"

    # Verify cached_balance updated on client
    assert_in_delta balance_after, @client.cached_balance, 1.5
  end

end

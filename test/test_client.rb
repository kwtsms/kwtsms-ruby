# frozen_string_literal: true

require_relative "test_helper"

# 2026-11-05 08:07 +03: phone numbers come from KWTSMS_TEST_NUMBER via test_helper.rb
# (env_test_number skips when unset); pass-through fields use the placeholder; bulk tests use
# generated numbers only against webmock stubs (never the network), int-testnumber.

class TestClientInitialization < Minitest::Test
  def test_creates_client_with_valid_credentials
    client = KwtSMS::Client.new("user", "pass")
    assert_equal "user", client.username
    assert_equal "KWT-SMS", client.sender_id
    refute client.test_mode
  end

  def test_creates_client_with_all_options
    client = KwtSMS::Client.new("user", "pass", sender_id: "MY-APP", test_mode: true, log_file: "")
    assert_equal "MY-APP", client.sender_id
    assert client.test_mode
    assert_equal "", client.log_file
  end

  def test_raises_on_empty_username
    assert_raises(ArgumentError) { KwtSMS::Client.new("", "pass") }
  end

  def test_raises_on_nil_password
    assert_raises(ArgumentError) { KwtSMS::Client.new("user", nil) }
  end

  def test_raises_on_nil_username
    assert_raises(ArgumentError) { KwtSMS::Client.new(nil, "pass") }
  end

  def test_cached_balance_nil_initially
    client = KwtSMS::Client.new("user", "pass")
    assert_nil client.cached_balance
    assert_nil client.cached_purchased
  end
end

class TestClientFromEnv < Minitest::Test
  def setup
    @original_env = ENV.to_h
  end

  def teardown
    ENV.replace(@original_env)
  end

  def test_from_env_with_env_vars
    ENV["KWTSMS_USERNAME"] = "ruby_username"
    ENV["KWTSMS_PASSWORD"] = "ruby_password"
    ENV["KWTSMS_SENDER_ID"] = "MY-SENDER"
    ENV["KWTSMS_TEST_MODE"] = "1"

    client = KwtSMS::Client.from_env
    assert_equal "ruby_username", client.username
    assert_equal "MY-SENDER", client.sender_id
    assert client.test_mode
  end

  def test_from_env_raises_without_credentials
    ENV.delete("KWTSMS_USERNAME")
    ENV.delete("KWTSMS_PASSWORD")
    assert_raises(ArgumentError) { KwtSMS::Client.from_env(env_file: "/nonexistent/.env") }
  end
end

class TestClientVerify < Minitest::Test
  def setup
    @client = KwtSMS::Client.new("user", "pass", log_file: "")
  end

  def test_verify_success
    stub_request(:post, "https://www.kwtsms.com/API/balance/")
      .to_return(
        status: 200,
        body: { "result" => "OK", "available" => "150.5", "purchased" => "200" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    ok, balance, err = @client.verify
    assert ok
    assert_in_delta 150.5, balance
    assert_nil err
    assert_in_delta 150.5, @client.cached_balance
    assert_in_delta 200.0, @client.cached_purchased
  end

  def test_verify_auth_error
    stub_request(:post, "https://www.kwtsms.com/API/balance/")
      .to_return(
        status: 403,
        body: { "result" => "ERROR", "code" => "ERR003", "description" => "Authentication error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    ok, balance, err = @client.verify
    refute ok
    assert_nil balance
    assert_includes err, "Authentication error"
    assert_includes err, "KWTSMS_USERNAME"
  end

  def test_verify_network_error
    stub_request(:post, "https://www.kwtsms.com/API/balance/")
      .to_timeout

    ok, balance, err = @client.verify
    refute ok
    assert_nil balance
    assert_includes err, "timed out"
  end
end

class TestClientSend < Minitest::Test
  def setup
    @client = KwtSMS::Client.new("user", "pass", log_file: "")
  end

  def test_send_success
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: {
          "result" => "OK", "msg-id" => "12345", "numbers" => 1,
          "points-charged" => 1, "balance-after" => 149
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "OK", result["result"]
    assert_equal "12345", result["msg-id"]
    assert_in_delta 149.0, @client.cached_balance
  end

  def test_send_with_invalid_phone
    result = @client.send_sms("abc", "Hello")
    assert_equal "ERROR", result["result"]
    assert_equal "ERR_INVALID_INPUT", result["code"]
    assert_includes result["description"], "no digits found"
  end

  def test_send_with_email
    result = @client.send_sms("user@email.com", "Hello")
    assert_equal "ERROR", result["result"]
    assert_includes result["description"], "email address"
  end

  def test_send_with_empty_message_after_cleaning
    result = @client.send_sms(env_test_number, "\u{1F600}\u{1F601}")
    assert_equal "ERROR", result["result"]
    assert_equal "ERR009", result["code"]
    assert_includes result["description"], "empty after cleaning"
  end

  def test_send_mixed_valid_invalid
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "123", "numbers" => 1,
                "points-charged" => 1, "balance-after" => 99 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms([env_test_number, "abc"], "Hello")
    assert_equal "OK", result["result"]
    assert result.key?("invalid")
    assert_equal 1, result["invalid"].length
    assert_includes result["invalid"][0]["error"], "no digits found"
  end

  def test_send_err003
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 403,
        body: { "result" => "ERROR", "code" => "ERR003", "description" => "Authentication error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    assert_equal "ERR003", result["code"]
    assert result.key?("action")
    assert_includes result["action"], "KWTSMS_USERNAME"
  end

  def test_send_err026
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR026", "description" => "Country not activated" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    assert_includes result["action"], "country"
  end

  def test_send_err025
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR025", "description" => "Invalid phone" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    assert_includes result["action"], "country code"
  end

  def test_send_err010
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR010", "description" => "Zero balance" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    assert_includes result["action"], "kwtsms.com"
  end

  def test_send_err024
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR024", "description" => "IP not whitelisted" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    assert_includes result["action"].downcase, "ip"
  end

  def test_send_err028
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR028", "description" => "Rate limit" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    # 2026-10-22 15:34 +03: ERR028 text no longer states a fixed 15 s.
    assert_includes result["action"], "too soon"
  end

  def test_send_err008
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR008", "description" => "Banned sender" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    assert result.key?("action")
  end

  def test_send_unknown_error_code
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR999", "description" => "Unknown error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    refute result.key?("action")
    assert_equal "Unknown error", result["description"]
  end

  def test_send_network_error
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_timeout

    result = @client.send_sms(env_test_number, "Hello")
    assert_equal "ERROR", result["result"]
    assert_equal "NETWORK", result["code"]
  end

  def test_send_deduplicates_numbers
    n = env_test_number
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .with { |req| JSON.parse(req.body)["mobile"] == n }
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "123", "numbers" => 1,
                "points-charged" => 1, "balance-after" => 99 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(["+#{n}", "00#{n}"], "Hello")
    assert_equal "OK", result["result"]
  end

  def test_send_with_sender_override
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .with { |req| JSON.parse(req.body)["sender"] == "CUSTOM" }
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "123", "numbers" => 1,
                "points-charged" => 1, "balance-after" => 99 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_sms(env_test_number, "Hello", sender: "CUSTOM")
    assert_equal "OK", result["result"]
  end
end

class TestClientSenderids < Minitest::Test
  def setup
    @client = KwtSMS::Client.new("user", "pass", log_file: "")
  end

  def test_senderids_success
    stub_request(:post, "https://www.kwtsms.com/API/senderid/")
      .to_return(
        status: 200,
        body: { "result" => "OK", "senderid" => ["KWT-SMS", "MY-APP"] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.senderids
    assert_equal "OK", result["result"]
    assert_equal ["KWT-SMS", "MY-APP"], result["senderids"]
  end

  def test_senderids_error
    stub_request(:post, "https://www.kwtsms.com/API/senderid/")
      .to_return(
        status: 403,
        body: { "result" => "ERROR", "code" => "ERR003", "description" => "Auth" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.senderids
    assert_equal "ERROR", result["result"]
    assert result.key?("action")
  end
end

class TestClientCoverage < Minitest::Test
  def setup
    @client = KwtSMS::Client.new("user", "pass", log_file: "")
  end

  def test_coverage_success
    stub_request(:post, "https://www.kwtsms.com/API/coverage/")
      .to_return(
        status: 200,
        body: { "result" => "OK", "prefixes" => ["965", "966"] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.coverage
    assert_equal "OK", result["result"]
  end

  def test_coverage_error
    stub_request(:post, "https://www.kwtsms.com/API/coverage/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR033", "description" => "No coverage" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.coverage
    assert_equal "ERROR", result["result"]
    assert_includes result["action"], "coverage"
  end
end

class TestClientValidate < Minitest::Test
  def setup
    @client = KwtSMS::Client.new("user", "pass", log_file: "")
  end

  def test_validate_success
    stub_request(:post, "https://www.kwtsms.com/API/validate/")
      .to_return(
        status: 200,
        body: {
          "result" => "OK",
          "mobile" => { "OK" => [TEST_NUMBER_PLACEHOLDER], "ER" => [], "NR" => [] }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.validate([env_test_number])
    assert_equal [TEST_NUMBER_PLACEHOLDER], result["ok"]
    assert_empty result["er"]
    assert_nil result["error"]
  end

  def test_validate_all_invalid
    result = @client.validate(["abc", ""])
    assert_empty result["ok"]
    assert_equal 2, result["rejected"].length
    assert_includes result["error"], "failed validation"
  end

  def test_validate_mixed
    stub_request(:post, "https://www.kwtsms.com/API/validate/")
      .to_return(
        status: 200,
        body: {
          "result" => "OK",
          "mobile" => { "OK" => [TEST_NUMBER_PLACEHOLDER], "ER" => [], "NR" => [] }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.validate([env_test_number, "abc"])
    assert_equal [TEST_NUMBER_PLACEHOLDER], result["ok"]
    assert_equal 1, result["rejected"].length
    assert_includes result["rejected"][0]["error"], "no digits found"
  end
end

class TestClientSendWithRetry < Minitest::Test
  def setup
    @client = KwtSMS::Client.new("user", "pass", log_file: "")
  end

  def test_send_with_retry_success_first_attempt
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "100", "numbers" => 1,
                "points-charged" => 1, "balance-after" => 99 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_with_retry(env_test_number, "Hello", max_retries: 2)
    assert_equal "OK", result["result"]
    assert_equal "100", result["msg-id"]
  end

  def test_send_with_retry_retries_on_err028
    call_count = 0
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return do
        call_count += 1
        if call_count <= 2
          { status: 200,
            body: { "result" => "ERROR", "code" => "ERR028", "description" => "Rate limit" }.to_json,
            headers: { "Content-Type" => "application/json" } }
        else
          { status: 200,
            body: { "result" => "OK", "msg-id" => "200", "numbers" => 1,
                    "points-charged" => 1, "balance-after" => 98 }.to_json,
            headers: { "Content-Type" => "application/json" } }
        end
      end

    # Stub sleep to avoid waiting in tests (2026-10-22 15:34 +03: wait is wait_seconds, no longer 16 s)
    @client.stub(:sleep, nil) do
      result = @client.send_with_retry(env_test_number, "Hello", max_retries: 3)
      assert_equal "OK", result["result"]
      assert_equal 3, call_count
    end
  end

  def test_send_with_retry_gives_up_after_max_retries
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR028", "description" => "Rate limit" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @client.stub(:sleep, nil) do
      result = @client.send_with_retry(env_test_number, "Hello", max_retries: 2)
      assert_equal "ERROR", result["result"]
      assert_equal "ERR028", result["code"]
    end
  end

  def test_send_with_retry_does_not_retry_other_errors
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR003", "description" => "Auth error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.send_with_retry(env_test_number, "Hello", max_retries: 3)
    assert_equal "ERROR", result["result"]
    assert_equal "ERR003", result["code"]
  end

  # 2026-10-22 15:34 +03: retry is off by default (max_retries 0), wait defaults to 10 s.
  def test_send_with_retry_default_does_not_retry
    call_count = 0
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return do
        call_count += 1
        { status: 200,
          body: { "result" => "ERROR", "code" => "ERR028", "description" => "Rate limit" }.to_json,
          headers: { "Content-Type" => "application/json" } }
      end

    result = @client.send_with_retry(env_test_number, "Hello")
    assert_equal "ERR028", result["code"]
    assert_equal 1, call_count
  end

  def test_send_with_retry_waits_wait_seconds
    call_count = 0
    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return do
        call_count += 1
        if call_count == 1
          { status: 200,
            body: { "result" => "ERROR", "code" => "ERR028", "description" => "Rate limit" }.to_json,
            headers: { "Content-Type" => "application/json" } }
        else
          { status: 200,
            body: { "result" => "OK", "msg-id" => "300", "numbers" => 1,
                    "points-charged" => 1, "balance-after" => 97 }.to_json,
            headers: { "Content-Type" => "application/json" } }
        end
      end

    slept = []
    @client.stub(:sleep, ->(s) { slept << s }) do
      result = @client.send_with_retry(env_test_number, "Hello", max_retries: 1)
      assert_equal "OK", result["result"]
    end
    assert_equal [10], slept
  end
end

class TestClientSendBulk < Minitest::Test
  def setup
    @client = KwtSMS::Client.new("user", "pass", log_file: "")
  end

  def test_bulk_send_splits_into_batches
    numbers = (1..201).map { |i| "9659876#{i.to_s.rjust(4, '0')}" }

    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "B1", "numbers" => 200,
                "points-charged" => 200, "balance-after" => 800 }.to_json,
        headers: { "Content-Type" => "application/json" }
      ).then
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "B2", "numbers" => 1,
                "points-charged" => 1, "balance-after" => 799 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @client.stub(:sleep, nil) do
      result = @client.send_sms(numbers, "Bulk test")
      assert_equal "OK", result["result"]
      assert result["bulk"]
      assert_equal 2, result["batches"]
      assert_equal ["B1", "B2"], result["msg-ids"]
      assert_equal 201, result["numbers"]
      assert_equal 201, result["points-charged"]
      assert_in_delta 799.0, result["balance-after"]
      assert_empty result["errors"]
    end
  end

  # 2026-11-05 08:07 +03: replaces the live 250-number bulk test (it sent to generated
  # numbers that belong to real people); same 200 + 50 batching, webmock only, int-testnumber.
  def test_bulk_send_250_numbers_batches_200_and_50
    numbers = (0...250).map { |i| format("9659876%04d", i) }
    batch_sizes = []

    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .with { |req| batch_sizes << JSON.parse(req.body)["mobile"].split(",").length }
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "B1", "numbers" => 200,
                "points-charged" => 200, "balance-after" => 800 }.to_json,
        headers: { "Content-Type" => "application/json" }
      ).then
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "B2", "numbers" => 50,
                "points-charged" => 50, "balance-after" => 750 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @client.stub(:sleep, nil) do
      result = @client.send_sms(numbers, "Bulk test 250 numbers")
      assert_equal "OK", result["result"]
      assert result["bulk"]
      assert_equal [200, 50], batch_sizes
      assert_equal 2, result["batches"]
      assert_equal %w[B1 B2], result["msg-ids"]
      assert_equal 250, result["numbers"]
      assert_equal 250, result["points-charged"]
      assert_in_delta 750.0, result["balance-after"]
      assert_in_delta 750.0, @client.cached_balance
      assert_empty result["errors"]
    end
  end

  def test_bulk_send_partial_failure
    numbers = (1..401).map { |i| "9659876#{i.to_s.rjust(4, '0')}" }

    stub_request(:post, "https://www.kwtsms.com/API/send/")
      .to_return(
        status: 200,
        body: { "result" => "OK", "msg-id" => "B1", "numbers" => 200,
                "points-charged" => 200, "balance-after" => 800 }.to_json,
        headers: { "Content-Type" => "application/json" }
      ).then
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR010", "description" => "Zero balance" }.to_json,
        headers: { "Content-Type" => "application/json" }
      ).then
      .to_return(
        status: 200,
        body: { "result" => "ERROR", "code" => "ERR010", "description" => "Zero balance" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @client.stub(:sleep, nil) do
      result = @client.send_sms(numbers, "Partial test")
      assert_equal "PARTIAL", result["result"]
      assert_equal 1, result["msg-ids"].length
      assert_equal 2, result["errors"].length
    end
  end
end

class TestClientEnvLoader < Minitest::Test
  def test_load_env_file_parses_correctly
    require "tempfile"
    file = Tempfile.new(".env")
    file.write(<<~ENV)
      # Comment
      KEY1=value1
      KEY2="quoted value"
      KEY3='single quoted'
      KEY4=value with spaces  # inline comment

      EMPTY_LINE_ABOVE=yes
    ENV
    file.close

    env = KwtSMS.load_env_file(file.path)
    assert_equal "value1", env["KEY1"]
    assert_equal "quoted value", env["KEY2"]
    assert_equal "single quoted", env["KEY3"]
    assert_equal "value with spaces", env["KEY4"]
    assert_equal "yes", env["EMPTY_LINE_ABOVE"]
  ensure
    file&.unlink
  end

  def test_load_env_missing_file
    env = KwtSMS.load_env_file("/nonexistent/file")
    assert_equal({}, env)
  end
end

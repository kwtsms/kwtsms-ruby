# frozen_string_literal: true

require "set"

module KwtSMS
  # InvalidEntry represents a phone number that failed local pre-validation.
  InvalidEntry = Struct.new(:input, :error, keyword_init: true) do
    def to_h
      { "input" => input, "error" => error }
    end
  end

  # kwtSMS API client. Zero external dependencies. Ruby 2.7+
  #
  # Server timezone: Asia/Kuwait (GMT+3).
  # unix-timestamp values in API responses are GMT+3 server time, not UTC.
  # Log timestamps written by this client are always UTC ISO-8601.
  #
  # Quick start:
  #   sms = KwtSMS::Client.from_env
  #   ok, balance, err = sms.verify
  #   result = sms.send_sms("965XXXXXXXX", "Your OTP for MYAPP is: 123456")
  #   result = sms.send_sms("965XXXXXXXX", "Hello", sender: "OTHER-ID")
  #   2026-11-05 08:07 +03: placeholder instead of a sample mobile number (it belongs to a real person), int-testnumber.
  #   balance = sms.balance
  class Client
    # 2026-11-05 14:19 +03: user_agent reader added, the User-Agent sent on every call (#939).
    attr_reader :username, :sender_id, :test_mode, :log_file,
                :cached_balance, :cached_purchased, :user_agent

    # @param username [String] API username (not your account phone number)
    # @param password [String] API password
    # @param sender_id [String] Sender ID shown on recipient's phone (default: "KWT-SMS")
    # @param test_mode [Boolean] When true, messages are queued but not delivered (default: false)
    # @param log_file [String] Path to JSONL log file. Set to "" to disable logging.
    # @param app_name [String] Optional product token of the calling app or plugin, e.g. "kwtsms-wordpress/3.5.2",
    #   sent before the library token in the User-Agent (2026-11-05 14:19 +03, #939).
    def initialize(username, password, sender_id: "KWT-SMS", test_mode: false, log_file: "kwtsms.log", app_name: "")
      raise ArgumentError, "username and password are required" if username.nil? || username.empty? || password.nil? || password.empty?

      # 2026-11-05 14:19 +03: identify the caller to the API (name and version only, no personal data), #939.
      @user_agent = KwtSMS.build_user_agent(app_name)
      @username = username
      @password = password
      @sender_id = sender_id
      @test_mode = test_mode
      @log_file = log_file
      @cached_balance = nil
      @cached_purchased = nil
    end

    # Redact password from inspect/to_s output to prevent accidental exposure
    # in logs, error trackers (Sentry, Bugsnag), or REPL sessions.
    def inspect
      "#<#{self.class} @username=#{@username.inspect} @sender_id=#{@sender_id.inspect} @test_mode=#{@test_mode}>"
    end
    alias_method :to_s, :inspect

    # Load credentials from environment variables, falling back to .env file.
    #
    # Required env vars:
    #   KWTSMS_USERNAME : API username
    #   KWTSMS_PASSWORD : API password
    #
    # Optional env vars:
    #   KWTSMS_SENDER_ID : Sender ID (default: "KWT-SMS")
    #   KWTSMS_TEST_MODE : "1" to queue without delivering (default: "0")
    #   KWTSMS_LOG_FILE  : JSONL log path (default: "kwtsms.log")
    def self.from_env(env_file: ".env")
      file_env = KwtSMS.load_env_file(env_file)

      get = lambda do |key, default = ""|
        val = ENV[key]
        return val unless val.nil?

        val = file_env[key]
        return val unless val.nil?

        default
      end

      username  = get.call("KWTSMS_USERNAME")
      password  = get.call("KWTSMS_PASSWORD")
      sender_id = get.call("KWTSMS_SENDER_ID", "KWT-SMS")
      test_mode = get.call("KWTSMS_TEST_MODE", "0") == "1"
      log_file  = get.call("KWTSMS_LOG_FILE", "kwtsms.log")

      missing = []
      missing << "KWTSMS_USERNAME" if username.empty?
      missing << "KWTSMS_PASSWORD" if password.empty?
      raise ArgumentError, "Missing credentials: #{missing.join(', ')}" unless missing.empty?

      new(username, password, sender_id: sender_id, test_mode: test_mode, log_file: log_file)
    end

    # Test credentials by calling /balance/.
    # Returns: [ok, balance, error]
    #   ok:      true/false
    #   balance: Float or nil
    #   error:   nil or error message string
    def verify
      data = KwtSMS.api_request("balance", creds, @log_file, @user_agent) # 2026-11-05 14:19 +03: UA (#939)
      if data["result"] == "OK"
        @cached_balance = data["available"].to_f
        @cached_purchased = data["purchased"].to_f
        [true, @cached_balance, nil]
      else
        data = KwtSMS.enrich_error(data)
        description = data["description"] || data["code"] || "Unknown error"
        action = data["action"]
        error = action ? "#{description} > #{action}" : description
        [false, nil, error]
      end
    rescue RuntimeError => e
      [false, nil, e.message]
    end

    # Get current balance via /balance/ API call.
    # Returns Float or nil on error (returns cached value if available).
    def balance
      ok, bal, = verify
      ok ? bal : @cached_balance
    end

    # List sender IDs registered on this account via /senderid/.
    # Returns a consistent hash. Never raises, never crashes.
    def senderids
      data = KwtSMS.api_request("senderid", creds, @log_file, @user_agent) # 2026-11-05 14:19 +03: UA (#939)
      if data["result"] == "OK"
        { "result" => "OK", "senderids" => data["senderid"] || [] }
      else
        KwtSMS.enrich_error(data)
      end
    rescue RuntimeError => e
      { "result" => "ERROR", "code" => "NETWORK", "description" => e.message,
        "action" => "Check your internet connection and try again." }
    end

    # List active country prefixes via /coverage/.
    # Returns the full API response hash with error enrichment.
    def coverage
      data = KwtSMS.api_request("coverage", creds, @log_file, @user_agent) # 2026-11-05 14:19 +03: UA (#939)
      KwtSMS.enrich_error(data)
    rescue RuntimeError => e
      { "result" => "ERROR", "code" => "NETWORK", "description" => e.message,
        "action" => "Check your internet connection and try again." }
    end

    # Validate and normalize phone numbers via /validate/.
    #
    # Numbers that fail local validation are rejected immediately with a clear error.
    # Numbers that pass local validation are sent to the kwtSMS /validate/ endpoint.
    #
    # @param phones [Array<String>] List of phone numbers to validate
    # @return [Hash] with keys: ok, er, nr, raw, error, rejected
    def validate(phones)
      valid_normalized = []
      pre_rejected = []

      Array(phones).each do |raw|
        is_valid, error, normalized = KwtSMS.validate_phone_input(raw)
        if is_valid
          valid_normalized << normalized
        else
          pre_rejected << { "input" => raw.to_s, "error" => error }
        end
      end

      result = {
        "ok" => [],
        "er" => pre_rejected.map { |r| r["input"] },
        "nr" => [],
        "raw" => nil,
        "error" => nil,
        "rejected" => pre_rejected
      }

      if valid_normalized.empty?
        result["error"] = if pre_rejected.length == 1
                            pre_rejected[0]["error"]
                          else
                            "All #{pre_rejected.length} phone numbers failed validation"
                          end
        return result
      end

      payload = creds.merge("mobile" => valid_normalized.join(","))
      begin
        data = KwtSMS.api_request("validate", payload, @log_file, @user_agent) # 2026-11-05 14:19 +03: UA (#939)
        if data["result"] == "OK"
          mobile = data["mobile"] || {}
          result["ok"] = mobile["OK"] || []
          result["er"] = (mobile["ER"] || []) + result["er"]
          result["nr"] = mobile["NR"] || []
          result["raw"] = data
        else
          data = KwtSMS.enrich_error(data)
          result["er"] = valid_normalized + result["er"]
          result["raw"] = data
          result["error"] = data["description"] || data["code"]
          result["error"] = "#{result['error']} > #{data['action']}" if data["action"]
        end
      rescue RuntimeError => e
        result["er"] = valid_normalized + result["er"]
        result["error"] = e.message
      end

      result
    end

    # Send SMS to one or more numbers.
    #
    # @param mobile [String, Array<String>] Phone number(s). Normalized automatically.
    # @param message [String] SMS text. Cleaned automatically.
    # @param sender [String, nil] Optional sender ID override for this call only.
    # @return [Hash] API response with result, msg-id, balance-after, etc.
    def send_sms(mobile, message, sender: nil)
      effective_sender = sender || @sender_id

      raw_list = mobile.is_a?(Array) ? mobile : [mobile]

      valid_numbers = []
      invalid = []

      raw_list.each do |raw|
        is_valid, error, normalized = KwtSMS.validate_phone_input(raw)
        if is_valid
          valid_numbers << normalized
        else
          invalid << { "input" => raw.to_s, "error" => error }
        end
      end

      if valid_numbers.empty?
        description = if invalid.length == 1
                        invalid[0]["error"]
                      else
                        "All #{invalid.length} phone numbers are invalid"
                      end
        return KwtSMS.enrich_error({
          "result" => "ERROR",
          "code" => "ERR_INVALID_INPUT",
          "description" => description,
          "invalid" => invalid
        })
      end

      # Deduplicate normalized numbers
      valid_numbers = valid_numbers.uniq

      # Clean message before routing
      cleaned_message = KwtSMS.clean_message(message)
      if cleaned_message.strip.empty?
        return KwtSMS.enrich_error({
          "result" => "ERROR",
          "code" => "ERR009",
          "description" => "Message is empty after cleaning (contained only emojis or invisible characters)."
        })
      end

      if valid_numbers.length > 200
        result = send_bulk(valid_numbers, cleaned_message, effective_sender)
      else
        payload = creds.merge(
          "sender" => effective_sender,
          "mobile" => valid_numbers.join(","),
          "message" => cleaned_message,
          "test" => @test_mode ? "1" : "0"
        )
        begin
          result = KwtSMS.api_request("send", payload, @log_file, @user_agent) # 2026-11-05 14:19 +03: UA (#939)
        rescue RuntimeError => e
          return {
            "result" => "ERROR",
            "code" => "NETWORK",
            "description" => e.message,
            "action" => "Check your internet connection and try again."
          }
        end
        if result["result"] == "OK" && result.key?("balance-after")
          @cached_balance = result["balance-after"].to_f
        else
          result = KwtSMS.enrich_error(result)
        end
      end

      result["invalid"] = invalid unless invalid.empty?
      result
    end

    # Send SMS, optionally retrying on ERR028 (duplicate SMS protection).
    #
    # ERR028 is opt-in per account (Duplicate SMS protection in the account's
    # API settings). When it is on and any number in the request was sent the
    # same message within the account's window (10 seconds by default,
    # configurable per account), the whole request is rejected and nothing is
    # charged. Retry is off by default: ERR028 is returned like any other error
    # unless max_retries > 0. All other errors are returned immediately.
    #
    # 2026-10-22 15:34 +03: retry off by default and wait is a parameter (default 10),
    # was a hardcoded 3 retries x 16 s. The ERR028 window is per account, not a fixed 15 s.
    #
    # @param mobile [String, Array<String>] Phone number(s)
    # @param message [String] Message text
    # @param sender [String, nil] Sender ID override
    # @param max_retries [Integer] Max ERR028 retries after first attempt (default 0, no retry)
    # @param wait_seconds [Numeric] Seconds to wait before each retry (default 10)
    # @return [Hash] Same shape as send_sms. Never raises.
    def send_with_retry(mobile, message, sender: nil, max_retries: 0, wait_seconds: 10)
      result = send_sms(mobile, message, sender: sender)
      retries = 0
      while result["code"] == "ERR028" && retries < max_retries
        sleep(wait_seconds)
        result = send_sms(mobile, message, sender: sender)
        retries += 1
      end
      result
    end

    private

    def creds
      { "username" => @username, "password" => @password }
    end

    # Internal: send to >200 pre-normalized numbers in batches of 200.
    def send_bulk(numbers, message, sender)
      batch_size = 200
      batch_delay = 0.5
      err013_wait = [30, 60, 120]

      batches = numbers.each_slice(batch_size).to_a
      total_batches = batches.length

      msg_ids = []
      errors = []
      total_nums = 0
      total_pts = 0
      last_balance = nil

      batches.each_with_index do |batch, i|
        payload = creds.merge(
          "sender" => sender,
          "mobile" => batch.join(","),
          "message" => message,
          "test" => @test_mode ? "1" : "0"
        )

        data = nil
        waits = [0] + err013_wait
        waits.each_with_index do |wait, attempt|
          sleep(wait) if wait > 0
          begin
            data = KwtSMS.api_request("send", payload, @log_file, @user_agent) # 2026-11-05 14:19 +03: UA (#939)
          rescue RuntimeError => e
            errors << { "batch" => i + 1, "code" => "NETWORK", "description" => e.message }
            data = nil
            break
          end
          break if data["code"] != "ERR013" || attempt == err013_wait.length
        end

        if data && data["result"] == "OK"
          msg_ids << (data["msg-id"] || "")
          total_nums += (data["numbers"] || batch.length).to_i
          total_pts += (data["points-charged"] || 0).to_i
          if data.key?("balance-after")
            last_balance = data["balance-after"].to_f
            @cached_balance = last_balance
          end
        elsif data && data["result"] == "ERROR"
          errors << {
            "batch" => i + 1,
            "code" => data["code"],
            "description" => data["description"]
          }
        end

        sleep(batch_delay) if i < total_batches - 1
      end

      ok_count = msg_ids.length
      overall = if ok_count == total_batches
                  "OK"
                elsif ok_count == 0
                  "ERROR"
                else
                  "PARTIAL"
                end

      {
        "result" => overall,
        "bulk" => true,
        "batches" => total_batches,
        "numbers" => total_nums,
        "points-charged" => total_pts,
        "balance-after" => last_balance,
        "msg-ids" => msg_ids,
        "errors" => errors
      }
    end
  end
end

# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "time"

module KwtSMS
  BASE_URL = "https://www.kwtsms.com/API/"

  # kwtSMS server runs at GMT+3 (Asia/Kuwait).
  # unix-timestamp values in API responses are server time, not UTC.
  SERVER_TIMEZONE = "Asia/Kuwait (GMT+3)"

  # Build the User-Agent "[app token ]kwtsms-ruby/<VERSION>". The app token is caller input: anything
  # outside printable ASCII is removed (CR/LF would split the header), whitespace runs become "-",
  # leading/trailing "-" are trimmed, and it is cut to 64 characters. Empty means the library token only.
  # 2026-11-05 14:19 +03: added so kwtSMS can count accounts per integration (#939).
  def self.build_user_agent(app_name = "")
    # 2026-11-08 13:37 +03: dashes trimmed by scanning; /\A-+|-+\z/ is quadratic on long "-" runs (CodeQL rb/polynomial-redos)
    app = app_name.to_s.gsub(/[^\x20-\x7e]+/, "").strip.gsub(/\s+/, "-")
    first = 0
    last = app.length
    first += 1 while first < last && app[first] == "-"
    last -= 1 while last > first && app[last - 1] == "-"
    app = app[first...last][0, 64]
    lib = "kwtsms-ruby/#{VERSION}"
    app.empty? ? lib : "#{app} #{lib}"
  end

  # POST to a kwtSMS REST/JSON API endpoint.
  #
  # Always sets Content-Type and Accept: application/json.
  # Strips password from log entry.
  # Returns parsed JSON hash.
  # Raises RuntimeError on network / HTTP / parse failure.
  # 2026-11-05 14:19 +03: user_agent parameter added, sent on every call (#939).
  def self.api_request(endpoint, payload, log_file = "", user_agent = nil)
    url = URI.parse("#{BASE_URL}#{endpoint}/")

    safe_payload = payload.transform_keys(&:to_s).each_with_object({}) do |(k, v), h|
      h[k] = k == "password" ? "***" : v
    end

    log_entry = {
      "ts" => Time.now.utc.iso8601,
      "endpoint" => endpoint,
      "request" => safe_payload,
      "response" => nil,
      "ok" => false,
      "error" => nil
    }

    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 15
      http.read_timeout = 15

      request = Net::HTTP::Post.new(url.path)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["User-Agent"] = user_agent || build_user_agent # 2026-11-05 14:19 +03: kwtsms-ruby/<version> (#939)
      request.body = JSON.generate(payload)

      response = http.request(request)
      body = response.body.to_s

      begin
        data = JSON.parse(body)
      rescue JSON::ParserError => e
        log_entry["error"] = "Invalid JSON response: #{e.message}"
        write_log(log_file, log_entry)
        raise RuntimeError, "Invalid JSON response: #{e.message}"
      end

      log_entry["response"] = data
      log_entry["ok"] = data["result"] == "OK"
      write_log(log_file, log_entry)

      # For HTTP errors (4xx/5xx), kwtSMS returns JSON error details in the body.
      # If we successfully parsed the JSON, return it like a normal response.
      return data

    rescue Net::OpenTimeout, Net::ReadTimeout => e
      err = "Network error: connection timed out"
      log_entry["error"] = err
      write_log(log_file, log_entry)
      raise RuntimeError, err

    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
           Errno::ECONNRESET, Errno::EPIPE, OpenSSL::SSL::SSLError, IOError => e
      err = "Network error: #{e.message}"
      log_entry["error"] = err
      write_log(log_file, log_entry)
      raise RuntimeError, err
    end
  end
end

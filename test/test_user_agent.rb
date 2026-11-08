# frozen_string_literal: true

# FILE:      test/test_user_agent.rb
# CREATED:   2026-11-05 14:19 +03
# TASK:      Vikunja #939 (int-measure-signups)
# AUTHOR:    M Alhassoun
# WHAT:      Unit tests for the User-Agent kwtsms-ruby/<VERSION> and the optional app_name token.
# WHY:       kwtSMS counts accounts per integration from the User-Agent; it must be exact and header-safe.
# USAGE:     bundle exec rake test (or bundle exec ruby -Ilib:test test/test_user_agent.rb)
# DEPENDS:   minitest, webmock (test_helper.rb); no network.

require_relative "test_helper"

class TestUserAgent < Minitest::Test
  LIB = "kwtsms-ruby/#{KwtSMS::VERSION}"

  def test_default_is_library_token
    ua = KwtSMS::Client.new("ruby_username", "ruby_password", log_file: "").user_agent
    assert_equal LIB, ua
    assert_match(%r{\Akwtsms-ruby/[0-9][0-9A-Za-z.+-]*\z}, ua)
  end

  def test_app_name_is_prepended
    c = KwtSMS::Client.new("ruby_username", "ruby_password", log_file: "", app_name: "kwtsms-wordpress/3.5.2")
    assert_equal "kwtsms-wordpress/3.5.2 #{LIB}", c.user_agent
  end

  def test_app_name_is_sanitized
    ua = KwtSMS.build_user_agent("my app\r\nX-Injected: 1")
    refute_includes ua, "\r"
    refute_includes ua, "\n"
    refute_includes ua, " X-Injected"
    assert ua.end_with?(" #{LIB}")
    assert_equal LIB, KwtSMS.build_user_agent("  - -  ")
    assert_equal 64, KwtSMS.build_user_agent("a" * 200).split(" ").first.length
  end

  def test_header_is_sent_on_request
    stub = stub_request(:post, "https://www.kwtsms.com/API/balance/")
           .with(headers: { "User-Agent" => "my-shop/2.1.0 #{LIB}" })
           .to_return(
             status: 200,
             body: { "result" => "OK", "available" => "1", "purchased" => "1" }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    c = KwtSMS::Client.new("ruby_username", "ruby_password", log_file: "", app_name: "my-shop/2.1.0")
    ok, _balance, err = c.verify
    assert ok, err
    assert_requested stub
  end

  # 2026-11-08 13:37 +03: dash trim by scanning (repo sweep, CodeQL)
  def test_dashes_trimmed_and_fast
    assert_equal "x #{LIB}", KwtSMS.build_user_agent("--x--")
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    KwtSMS.build_user_agent("-" * 200_000 + "a")
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0, :<, 1.0
  end
end

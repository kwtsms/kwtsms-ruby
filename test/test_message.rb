# frozen_string_literal: true

require_relative "test_helper"

class TestCleanMessage < Minitest::Test
  def test_plain_text_unchanged
    assert_equal "Hello world", KwtSMS.clean_message("Hello world")
  end

  def test_strips_emoji
    assert_equal "Hello  world", KwtSMS.clean_message("Hello \u{1F600} world")
  end

  def test_strips_multiple_emojis
    result = KwtSMS.clean_message("\u{1F600}\u{1F601}\u{1F602}")
    assert_equal "", result
  end

  def test_converts_arabic_indic_digits
    assert_equal "12345", KwtSMS.clean_message("\u0661\u0662\u0663\u0664\u0665")
  end

  def test_converts_extended_arabic_indic_digits
    assert_equal "12345", KwtSMS.clean_message("\u06F1\u06F2\u06F3\u06F4\u06F5")
  end

  def test_strips_html_tags
    assert_equal "Hello world", KwtSMS.clean_message("<b>Hello</b> <i>world</i>")
  end

  def test_strips_multiline_html
    assert_equal "content", KwtSMS.clean_message("<div\nclass=\"x\">content</div>")
  end

  def test_strips_bom
    assert_equal "Hello", KwtSMS.clean_message("\uFEFFHello")
  end

  def test_strips_zero_width_space
    assert_equal "Hello", KwtSMS.clean_message("He\u200Bllo")
  end

  def test_strips_zero_width_non_joiner
    assert_equal "Hello", KwtSMS.clean_message("He\u200Cllo")
  end

  def test_strips_zero_width_joiner
    assert_equal "Hello", KwtSMS.clean_message("He\u200Dllo")
  end

  def test_strips_soft_hyphen
    assert_equal "Hello", KwtSMS.clean_message("He\u00ADllo")
  end

  def test_strips_word_joiner
    assert_equal "Hello", KwtSMS.clean_message("He\u2060llo")
  end

  def test_strips_object_replacement_char
    assert_equal "Hello", KwtSMS.clean_message("He\uFFFCllo")
  end

  def test_strips_directional_marks
    assert_equal "Hello", KwtSMS.clean_message("He\u200Ello\u200F")
  end

  def test_strips_directional_formatting
    assert_equal "Hello", KwtSMS.clean_message("\u202AHe\u202Bllo\u202C")
  end

  def test_strips_directional_isolates
    assert_equal "Hello", KwtSMS.clean_message("\u2066He\u2067llo\u2069")
  end

  def test_preserves_arabic_text
    arabic = "\u0645\u0631\u062D\u0628\u0627"
    assert_equal arabic, KwtSMS.clean_message(arabic)
  end

  def test_preserves_newlines
    assert_equal "Hello\nworld", KwtSMS.clean_message("Hello\nworld")
  end

  def test_preserves_tabs
    assert_equal "Hello\tworld", KwtSMS.clean_message("Hello\tworld")
  end

  def test_strips_c0_controls_except_newline_tab
    # \x01 is a C0 control character (SOH)
    assert_equal "Hello", KwtSMS.clean_message("He\x01llo")
  end

  def test_strips_del_character
    assert_equal "Hello", KwtSMS.clean_message("He\x7Fllo")
  end

  def test_strips_c1_controls
    # U+0085 is NEL (C1 control)
    assert_equal "Hello", KwtSMS.clean_message("He\u0085llo")
  end

  def test_strips_variation_selectors
    assert_equal "Hello", KwtSMS.clean_message("He\uFE0Fllo")
  end

  def test_strips_keycap
    assert_equal "Hello", KwtSMS.clean_message("He\u20E3llo")
  end

  def test_strips_flag_indicators
    # Regional indicator symbols (U+1F1E0-U+1F1FF)
    assert_equal "Hello", KwtSMS.clean_message("He\u{1F1F0}\u{1F1FC}llo")
  end

  def test_strips_tag_block
    assert_equal "Hello", KwtSMS.clean_message("He\u{E0001}llo")
  end

  def test_strips_mahjong_tiles
    assert_equal "Hello", KwtSMS.clean_message("He\u{1F004}llo")
  end

  def test_empty_after_cleaning
    result = KwtSMS.clean_message("\u{1F600}\u{1F601}")
    assert_equal "", result
  end

  def test_arabic_digits_in_message
    assert_equal "Your OTP is 1234", KwtSMS.clean_message("Your OTP is \u0661\u0662\u0663\u0664")
  end

  def test_mixed_cleanup
    input = "<b>Hello</b> \u{1F600} \uFEFF\u0661\u0662\u0663"
    result = KwtSMS.clean_message(input)
    assert_equal "Hello  123", result
  end

  # 2026-11-08 13:37 +03: strip_tags equals the old regex and stays linear (repo sweep, CodeQL)
  def test_strip_tags_matches_old_regex
    ["", "plain", "<b>x</b>", "a < b and c > d", "<a <b>", "<<<", ">>><<", "x<y", "<scr<script>ipt>", "a<b>c<d", "<>"].each do |c|
      assert_equal c.gsub(/<[^>]*>/, ""), KwtSMS.strip_tags(c), c.inspect
    end
  end

  def test_strip_tags_is_linear
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    KwtSMS.strip_tags("<" * 200_000)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0, :<, 1.0
  end
end

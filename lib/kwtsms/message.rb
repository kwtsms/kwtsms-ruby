# frozen_string_literal: true

module KwtSMS
  # Hidden / invisible characters that break SMS delivery
  HIDDEN_CHARS = [
    "\u200B", # zero-width space
    "\u200C", # zero-width non-joiner
    "\u200D", # zero-width joiner
    "\u2060", # word joiner
    "\u00AD", # soft hyphen
    "\uFEFF", # BOM / zero-width no-break space
    "\uFFFC"  # object replacement character
  ].freeze

  # Directional formatting characters
  DIRECTIONAL_CHARS = [
    "\u200E", # left-to-right mark
    "\u200F", # right-to-left mark
    "\u202A", "\u202B", "\u202C", "\u202D", "\u202E", # LRE, RLE, PDF, LRO, RLO
    "\u2066", "\u2067", "\u2068", "\u2069"             # LRI, RLI, FSI, PDI
  ].freeze

  STRIP_CHARS_SET = (HIDDEN_CHARS + DIRECTIONAL_CHARS).to_set.freeze

  # Check if a Unicode codepoint is an emoji or pictographic symbol that breaks SMS delivery.
  def self.emoji_codepoint?(cp)
    (cp >= 0x1F600 && cp <= 0x1F64F) ||   # emoticons
      (cp >= 0x1F300 && cp <= 0x1F5FF) ||  # misc symbols and pictographs
      (cp >= 0x1F680 && cp <= 0x1F6FF) ||  # transport and map
      (cp >= 0x1F700 && cp <= 0x1F77F) ||  # alchemical symbols
      (cp >= 0x1F780 && cp <= 0x1F7FF) ||  # geometric shapes extended
      (cp >= 0x1F800 && cp <= 0x1F8FF) ||  # supplemental arrows-C
      (cp >= 0x1F900 && cp <= 0x1F9FF) ||  # supplemental symbols and pictographs
      (cp >= 0x1FA00 && cp <= 0x1FA6F) ||  # chess symbols
      (cp >= 0x1FA70 && cp <= 0x1FAFF) ||  # symbols and pictographs extended-A
      (cp >= 0x2600 && cp <= 0x26FF) ||    # miscellaneous symbols
      (cp >= 0x2700 && cp <= 0x27BF) ||    # dingbats
      (cp >= 0xFE00 && cp <= 0xFE0F) ||    # variation selectors
      (cp >= 0x1F000 && cp <= 0x1F0FF) ||  # mahjong tiles + playing cards
      (cp >= 0x1F1E0 && cp <= 0x1F1FF) ||  # regional indicator symbols (country flags)
      cp == 0x20E3 ||                       # combining enclosing keycap
      (cp >= 0xE0000 && cp <= 0xE007F)     # tags block (subdivision flags)
  end

  # Clean SMS message text before sending to kwtSMS.
  #
  # Called automatically by KwtSMS::Client#send. No manual call needed.
  #
  # Strips content that silently breaks delivery:
  # - Arabic-Indic / Extended Arabic-Indic digits converted to Latin digits
  # - Emojis and pictographic symbols (silently stuck in queue)
  # - Hidden control characters: BOM, zero-width space, soft hyphen, etc.
  # - Directional formatting characters
  # - C0/C1 control characters (except \n and \t)
  # - HTML tags (causes ERR027)
  #
  # Does NOT strip Arabic letters. Arabic text is fully supported.
  # Returns "" if the entire message was emoji or invisible characters.
  # Removes HTML tags: same result as text.gsub(/<[^>]*>/, "") but linear on long runs of "<".
  # 2026-11-08 13:37 +03: repo sweep (CodeQL rb/polynomial-redos).
  def self.strip_tags(text)
    out = +""
    i = 0
    while i < text.length
      lt = text.index("<", i)
      break if lt.nil?
      gt = text.index(">", lt + 1)
      break if gt.nil?
      out << text[i...lt]
      i = gt + 1
    end
    out << text[i..-1].to_s
    out
  end

  def self.clean_message(text)
    text = text.to_s

    # 1. Convert Arabic-Indic and Extended Arabic-Indic digits to Latin
    text = text.tr(ARABIC_DIGITS + EXTENDED_ARABIC_DIGITS, LATIN_DIGITS)

    # 2. Strip HTML tags
    text = strip_tags(text) # 2026-11-08 13:37 +03: linear, same result as gsub(/<[^>]*>/, "") (CodeQL rb/polynomial-redos)

    # 3. Remove emojis and pictographic characters, hidden chars, directional chars,
    #    and C0/C1 control characters (except \n and \t)
    text = text.each_char.select do |c|
      cp = c.ord
      next false if emoji_codepoint?(cp)
      next false if STRIP_CHARS_SET.include?(c)
      # C0 controls (U+0000..U+001F) except TAB (0x09) and LF (0x0A)
      next false if cp <= 0x1F && cp != 0x09 && cp != 0x0A
      # DEL
      next false if cp == 0x7F
      # C1 controls (U+0080..U+009F)
      next false if cp >= 0x80 && cp <= 0x9F

      true
    end.join

    text
  end
end

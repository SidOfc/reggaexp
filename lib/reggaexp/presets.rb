# frozen_string_literal: true

# Reggaexp main module
module Reggaexp
  # characters that need to be escaped outside and within a
  # character-class respectively.
  ESCAPE                 = %w[{ } ( ) [ ] | ? * + . ^ $ \\].freeze
  CHARACTER_CLASS_ESCAPE = %w{- ] \\}.freeze
  PRESETS                = {
    word:        '\w',
    non_word:    '\W',
    number:      0..9,
    non_numeric: '\D',
    letter:      'a'..'Z',
    upper:       'A'..'Z',
    lower:       'a'..'z',
    whitespace:  '\s',
    space:       ' ',
    tab:         '\t',
    dot:         '.',
    blank:       %i[space tab],
    hex:         [:number, 'a'..'F'],
    alphanum:    %i[letter number]
  }.freeze

  PRESET_ALIASSES = {
    digit:     :number,
    non_digit: :non_numeric,
    char:      :letter,
    character: :letter,
    any:       :dot
  }.freeze

  PRESET_KEYS = (PRESETS.keys + PRESET_ALIASSES.keys)
                .flat_map { |k| [k, "#{k}s".to_sym] }.freeze
end

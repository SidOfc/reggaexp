# frozen_string_literal: true

# Reggaexp main module
module Reggaexp
  # Reggaexp::Engine
  class Engine
    attr_reader :clauses, :flags

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

    def initialize(&block)
      @clause_opts = []
      @clauses     = []
      @flags       = []
      @pattern     = nil
      @block       = block if block_given?

      instance_eval(&@block) if @block
    end

    def reset
      @clause_opts = []
      @clauses     = []
      @flags       = []
      @pattern     = nil

      instance_eval(&@block) if @block

      self
    end

    # set flags of regular expression
    def add_flags(*flag_args)
      @pattern = nil
      @flags   = (@flags + flag_args).uniq

      self
    end
    alias add_flag add_flags

    def remove_flags(*flag_args)
      @pattern  = nil
      @flags   -= flag_args

      self
    end
    alias remove_flag remove_flags

    def clear_flags!
      @pattern = nil
      @flags   = []

      self
    end

    # parses arguments given to any function like #one_or_more or #between
    # and processes it to produce the right clauses.
    # range boundaries, numeric values and boolean values will be stringified
    # e.g. true # => 'true'
    #      1.25 # => '1\.25'
    #      1..4 # => '1'..'4'
    # we can do this because it will not matter for the regular expression
    # and we get an added benefit of simplifying a lot of comparisons since
    # we don't have to worry about 4 == '4' when deduplicating for example.
    def parse(*args, **opts, &block)
      @pattern = nil
      return parse_block(**opts, &block) if block_given?

      flat_args = args.flatten
      flat_args = with_presets flat_args
      atoms     = [*ranges(flat_args), *numerics(flat_args),
                   *strings(flat_args), *symbols(flat_args),
                   *bools(flat_args)].uniq

      opts[:unescape_dot] = true if args.include? :any
      append_clause atoms, opts
      self
    end

    # when a block is given, parse it in a new instance of self
    # and append it as a clause
    def parse_block(**opts, &block)
      sub_pattern = self.class.new(&block)
      append_clause sub_pattern.parse, opts
    end

    # filter elements for a character class
    def character_class(flat_args)
      flat_args.select { |a| a.is_a?(String) && a.tr('\\', '').length <= 1 } +
        flat_args.select(&Range.method(:===))
    end

    # filter elements for a non-capturing group
    def non_capturing_group(flat_args)
      flat_args.select { |a| a.is_a?(String) && a.tr('\\', '').length > 1 }
    end

    # stringify boolean values to their string counterparts
    # e.g. true  # => 'true'
    #      false # => 'false'
    def bools(flat_args)
      # rubocop:disable Style/CaseEquality
      flat_args.select { |b| b === true || b === false }
               .map(&:to_s).uniq
      # rubocop:enable Style/CaseEquality
    end

    # filter symbols and treat them like regular strings / chars
    def symbols(flat_args)
      strings flat_args.select(&Symbol.method(:===)).map(&:to_s)
    end

    # filter symbol presets recursively
    def with_presets(flat_args)
      presets = flat_args.select(&Symbol.method(:===)).flat_map do |preset|
        singular = preset.to_s.gsub(/(?<=.)s\z/, '').to_sym
        singular = PRESET_ALIASSES.fetch singular, singular
        value    = PRESETS[singular]

        next map_preset_array value if value.is_a? Array

        value
      end.compact

      (flat_args - PRESET_KEYS) | presets
    end

    # recursively walk symbol arrays to find their
    # actual preset value
    def map_preset_array(preset_values)
      preset_values.flat_map do |value|
        case value
        when Array then map_preset_array value
        when Symbol
          next PRESETS[value] || value unless PRESETS[value].is_a? Array

          map_preset_array PRESETS[value]
        else
          value
        end
      end
    end

    # escape strings based on their length. if a string is only one character
    # in size then it will be placed in a character class and needs a specific
    # escape method. otherwise regular escape is applied
    def strings(flat_args)
      flat_args.select(&String.method(:===)).map do |str|
        mtd = str.tr('\\', '').length == 1 ? :character_class_escape : :escape
        send mtd, str
      end.uniq
    end

    # stringifies and escapes numeric arguments
    def numerics(flat_args)
      flat_args.select(&Numeric.method(:===))
               .map(&:to_s).uniq.map(&method(:escape))
    end

    # sorts and parses ranges from flat list of arguments
    # it will remove ranges that are contained within another range
    # and then merge connecting numeric and character ranges
    def ranges(flat_args)
      ranges = stringify_range_bounds flat_args.select(&Range.method(:===))
      ranges = remove_subranges explode_multi_case_ranges ranges

      merge_ranges(ranges.select(&method(:numeric_range?))) +
        merge_ranges(ranges.select(&method(:character_range?)))
    end

    # always get proper boundaries of ranges
    # this is relevant for mixed-case ranges like 'a'..'Z'
    # because Range#minmax does not return ['a', 'Z'] but ['', '']
    def range_bounds(range)
      [range.first, range.last]
    end

    # turns 'a'..'Z' and 'A'..'z' into [a-zA-Z]
    def explode_multi_case_ranges(ranges)
      ranges.map(&method(:range_bounds)).each_with_object [] do |bounds, ary|
        if mixed_case_bounds? bounds
          ary << Range.new(*bounds.map(&:downcase))
          ary << Range.new(*bounds.map(&:upcase))
        else
          ary << Range.new(*bounds)
        end
      end
    end

    # check if range has a lowercase and uppercase boundary
    def mixed_case_bounds?(bounds)
      bounds.any? { |b| /[[:lower:]]/.match b } &&
        bounds.any? { |b| /[[:upper:]]/.match b }
    end

    # build the actual pattern
    def pattern
      @pattern ||= Regexp.compile compiled_pattern, flag_value
    end

    def compiled_pattern
      clauses.map.with_index do |atoms, idx|
        strs = exprs_from_atoms atoms, **info_for_clause(idx)

        next parse_atom idx, strs.first if strs.size == 1
        next parse_atom idx, strs.join('|'), non_capture: !in_or? if strs.any?

        parse_atom idx, ''
      end.join
    end

    # comparison operators
    def match(other, pos = 0)
      pattern.match other, pos
    end

    def match?(other, pos = 0)
      pattern.match? other, pos
    end

    def !~(other)
      pattern !~ other
    end

    def =~(other)
      pattern =~ other
    end

    def !=(other)
      pattern != other
    end

    def ==(other)
      pattern == other
    end

    def ===(other)
      # rubocop:disable Style/CaseEquality
      pattern === other
      # rubocop:enable Style/CaseEquality
    end

    def <=>(other)
      pattern <=> other
    end

    def ~
      # rubocop:disable Style/SpecialGlobalVars
      self =~ $_
      # rubocop:enable Style/SpecialGlobalVars
    end

    def method_missing(mtd, *args, &block)
      super unless regexp_method? mtd

      pattern.send mtd, *args, &block
    end

    def respond_to_missing?(mtd, _include_private = false)
      regexp_method? mtd
    end

    def regexp_method?(sym)
      Regexp.instance_methods.include? sym
    end

    def alternating_or?
      clauses  = @clause_opts.map { |h| h.key?(:or) }
      expected = !clauses.shift

      clauses.all? do |bool|
        alternated = bool == expected
        expected   = !expected

        alternated
      end
    end

    def or_prev?(**opts)
      info_for_clause(opts[:clause] - 1).key? :or
    end

    def or_next?(**opts)
      info_for_clause(opts[:clause] + 1).key? :or
    end

    # parse atoms from a single 'parse' call
    # the content argument will be the atoms stringified
    def parse_atom(clause_idx, content, **opts)
      opts = info_for_clause(clause_idx).merge opts

      maybe_prepend(nil, **opts) +
        maybe_with_capture(content, **opts) +
        maybe_append(nil, **opts)
    end

    def in_or?
      @in_or ? true : false
    end

    def maybe_prepend(content, **opts)
      if !alternating_or? && !or_prev?(**opts) && or_next?(**opts)
        @in_or = true
        opening = '(?:'
      end

      return "#{opening}#{content}" unless opts.key? :prepend

      "#{opening}#{opts[:prepend]}#{content}"
    end

    def maybe_append(content, **opts)
      if !alternating_or? && !or_next?(**opts) && or_prev?(**opts)
        @in_or = false
        closing = ')'
      end

      return "#{content}#{closing}" unless opts.key? :append

      "#{content}#{opts[:append]}#{closing}"
    end

    # removes redundant quantifiers like {1,} or {1}
    def maybe_simplify_quantifier(quantifier)
      if quantifier.is_a?(Array) || quantifier.is_a?(Range)
        min, max = [quantifier.first, quantifier.last].map(&:to_i)
        no_end   = quantifier.last.nil?

        # rubocop doesn't support Ruby < 2.2.0 anymore
        # rubocop:disable Style/NumericPredicate
        return ''  if min == max && min == 1
        return '+' if no_end     && min == 1
        return '*' if no_end     && min == 0
        return '?' if min == 0   && max == 1
        # rubocop:enable Style/NumericPredicate
      end

      quantifier
    end

    # check if a quantifier is present in opts and process it
    def maybe_with_quantifier(content, **opts)
      q = opts.fetch :quantifier, nil
      q = maybe_simplify_quantifier q

      return "#{content}{#{q.first},#{q.last}}" if q.is_a?(Array) ||
                                                   q.is_a?(Range)

      return "#{content}{#{q}}" if q.to_s =~ /\A\d+\z/

      "#{content}#{q}"
    end

    # check if either a capture or non capture group must be generated
    # from given opts.
    def maybe_with_capture(content, **opts)
      name      = opts.fetch :as, nil
      capture   = opts.fetch :capture, name ? true : false
      non_capt  = opts.fetch :non_capture, false
      capt_type = non_capt ? '?:' : ''

      return '|' if opts.key? :or

      str  = (capture || non_capt ? '(' : '')
      str += (name ? "?<#{name}>" : capt_type)
      str += maybe_with_quantifier(content, **opts)
      str + (capture || non_capt ? ')' : '')
    end

    # converts ranges to correct min-max format and puts
    # all single chars in one character class
    def exprs_from_atoms(atoms, **opts)
      return sub_expr(atoms, **opts) if atoms.is_a? self.class

      atoms     = atoms_after_flags atoms
      chars     = character_class atoms
      chars     = chars.map { |c| c.is_a?(Range) ? range_bounds(c).join('-') : c }
      strs      = non_capturing_group atoms
      opt_group = chars.size == 1 && chars.first !~ /\A.-.\z/

      if opt_group
        char = escape unescape(chars.first)
        char = char.gsub('\\.', '.') if opts.key? :unescape_dot
        strs << char
      elsif chars.any?
        strs << "#{opt_group ? '' : '['}#{chars.join}#{opt_group ? '' : ']'}"
      end

      strs
    end

    def pattern_entirely_grouped?(chars = nil)
      group_level     = 0
      pattern_array   = chars || pattern.inspect.gsub(/\/\w*\z/, '/')[1..-2].split(/(?=\\)|(?<!\\)/)
      frst, *mdl, lst = pattern_array.map do |char|
        case char
        when '('
          group_level += 1
          group_level - 1
        when ')' then group_level -= 1
        else group_level
        end
      end

      mdl.all? { |l| l > frst && l > lst }
    end

    def sub_expr(reggaexp, **opts)
      outer_capture = opts[:capture] || opts[:as] || opts[:non_capture]
      pat           = reggaexp.clear_flags!.add_flags(*flags).pattern
                              .inspect.gsub(%r{\$?/\w*\z}, '/')
                              .gsub(%r{(?<!\\)\\[Az]}, '')[1..-2]

      return [pat.gsub(%r{\A\^}, '')] \
        unless outer_capture && reggaexp.pattern_entirely_grouped?

      [pat.gsub(%r{\)\z}, '')
          .gsub(%r{\A\^?\((?:\?(?:(?:<?[!=])|<\w+>|:))?}, '')]
    end

    # apply flags to atoms and remove duplicates
    def atoms_after_flags(flat_args)
      strs = flat_args.reject(&Range.method(:===))
      rngs = flat_args.select(&Range.method(:===))

      if @flags.include? :i
        strs = strs.map(&:downcase)
        rngs = rngs.map { |r| Range.new(*range_bounds(r).map(&:downcase)) }
      end

      (strs + rngs).uniq
    end

    # grab options passed for a given #parse call
    def info_for_clause(idx)
      @clause_opts.detect { |h| h[:clause] == idx } || {}
    end

    # append an clause to the end of the pattern and return self.
    def append_clause(content, opts)
      @clause_opts << opts.merge(clause: @clauses.size)
      @clauses     << content

      self
    end

    # returns all ranges in args with their #min and #max converted
    # to a string to allow for easier filtering of duplicates.
    def stringify_range_bounds(ranges)
      ranges.map { |r| Range.new(r.first.to_s, r.last.to_s) }
    end

    # remove subranges from an array of ranges given in args.
    def remove_subranges(rngs)
      rngs.reject { |r| (rngs - [r]).any? { |rng| range_overlaps?(rng, r) } }
    end

    # merge connecting ranges:
    #   a..d, e..g => a..g
    #   a..d, f..g => a..d, f..g
    #
    # this method does not take care of sorting types of ranges
    # this must be done manually using the provided
    # #numeric_range? and #character_range? helpers for example
    def merge_ranges(ranges)
      initial, ranges = sorted_merge_ranges ranges

      ranges.each_with_object initial do |rng, merged|
        prev_range = merged.last

        next merged << rng unless prev_range.last.ord >= rng.first.ord - 1

        merged[-1] = prev_range.first..[prev_range.last, rng.last].max
      end
    end

    # returns ranges sorted by minimum value
    # if no ranges are present, value will be [[], []]
    # if one range is supplied, value will be [[r1], [r1]]
    # if more ranges are supplied, value will be [[r1], [r2, ... rN]]
    def sorted_merge_ranges(ranges)
      ranges = ranges.sort_by(&:first)
      first  = [ranges.first].compact

      [first, ranges[1..-1] || first]
    end

    # check wether given range has numeric boundaries
    def numeric_range?(range)
      return false unless range.respond_to?(:first) && range.respond_to?(:last)

      range.first =~ /\A\d\z/ && range.last =~ /\A\d\z/ ? true : false
    end

    # check wether given range has character boundaries
    def character_range?(range)
      return false unless range.respond_to?(:first) && range.respond_to?(:last)

      range.first =~ /\A\D\z/ && range.last =~ /\A\D\z/ ? true : false
    end

    # check wether rng1 overlaps rng2
    def range_overlaps?(rng1, rng2)
      rng2.first >= rng1.first && rng2.last <= rng1.last
    end

    # escape special characters in given input string
    # this method must only be used outside of character-class
    # context. see #character_class_escape to escape characters
    # inside a character-class-context
    def escape(input)
      input.to_s.split(/(?=\\)|(?<!\\)/).map do |c|
        ESCAPE.include?(c) ? "\\#{c}" : c
      end.join
    end

    # like escape but for a character-class input string
    # a character-class only requires few characters to
    # be escaped like '-' and ']' unlike regular escape.
    def character_class_escape(input)
      input.to_s.split(/(?=\\)|(?<!\\)/).map do |c|
        CHARACTER_CLASS_ESCAPE.include?(c) ? "\\#{c}" : c
      end.join
    end

    def unescape(input)
      res = (ESCAPE | CHARACTER_CLASS_ESCAPE).reduce input do |str, esc|
        str.gsub(/\\(#{escape(esc)})/, '\1')
      end

      res
    end

    # parse value of known flags into Regexp.compile
    # compatible integer
    def flag_value
      @flags.reduce(0) do |val, flag|
        case flag.to_sym
        when :m then val | Regexp::MULTILINE
        when :i then val | Regexp::IGNORECASE
        when :x then val | Regexp::EXTENDED
        end
      end
    end
  end
end

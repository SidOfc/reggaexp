# frozen_string_literal: true

# Reggaexp main module
module Reggaexp
  # Reggaexp::Base includes all the core logic for the public interface
  class Base
    ESCAPE                 = %w[{ } ( ) [ ] | ? * + . ^ $].freeze
    CHARACTER_CLASS_ESCAPE = %w{- ]}.freeze

    SIMPLIFY = {
      '{1}'   => '',
      '{1,}'  => '+',
      '{0,}'  => '*',
      '{0,1}' => '?'
    }.freeze

    MAPPING = {
      word_character:         '\w',
      non_word_character:     '\W',
      whitespace:             '\s',
      non_whitespace:         '\S',
      tab:                    '\t',
      space:                  ' ',

      digit:                  '0-9',

      uppercase_letter:       'A-Z',
      lowercase_letter:       'a-z',
      letter:                 %i[lowercase_letter uppercase_letter],

      alphanumeric:           %i[letter digit],
      uppercase_alphanumeric: %i[uppercase_letter digit],
      lowercase_alphanumeric: %i[lowercase_letter digit]
    }.freeze

    def initialize
      @str   = ''
      @flags = []
    end

    def add_flag(flag)
      @flags << flag unless @flags.include? flag
      @regexp = nil

      self
    end

    def remove_flag(flag)
      @flags.delete flag
      @regexp = nil

      self
    end

    def !~(other)
      regexp !~ other
    end

    def =~(other)
      regexp =~ other
    end

    def !=(other)
      regexp != other
    end

    def ==(other)
      regexp == other
    end

    def <=>(other)
      regexp <=> other
    end

    def to_s
      "#<#{self.class.name}:#{object_id} regexp=/#{@str}/#{@flags.join}>"
    end

    def inspect
      to_s
    end

    def regexp
      @regexp ||= Regexp.new @str, flag_value
    end

    def write(fmt, *args, **opts, &block)
      atom = format fmt, block ? scoped { instance_eval(&block) } : parse(*args, **opts)
      @str = opts[:prepend] ? "#{atom}#{@str}" : "#{@str}#{atom}"
      @regexp = nil

      self
    end

    def simplify(atom)
      SIMPLIFY.fetch atom, atom
    end

    def parse(*args, **opts)
      args[0] = args[0].to_s if args.size == 1 && args.first.is_a?(Numeric)

      case args.first
      when Range, Symbol, String
        constraint(*args, **opts)
      when Array, Numeric
        range_constraint(args.first, args[1..-1], **opts)
      else
        args.first.to_s
      end
    end

    def range_constraint(amount, constraints = [], **opts)
      min, max = amount if amount.is_a? Array
      range    = simplify(min || max ? "{#{min},#{max}}" : "{#{amount}}")

      "#{constraint(*constraints, **opts)}#{range}"
    end

    def escape(pattern)
      pattern.to_s.chars.map { |c| ESCAPE.include?(c) ? "\\#{c}" : c }.join
    end

    def character_class_escape(pattern)
      pattern.to_s.chars.map { |c| CHARACTER_CLASS_ESCAPE.include?(c) ? "\\#{c}" : c }.join
    end

    def constraint(*args, **opts)
      if args.select(&String.method(:===)).map(&:size).max.to_i < 2
        character_class args, **opts
      else
        non_capture_group args, **opts
      end
    end

    def groups(args)
      map_patterns(*args).each_with_object [[], []] do |pat, lists|
        if args.include?(pat) && pat.to_s.size > 1
          lists[0] << escape(pat)
        else
          lists[1] << pat.to_s.gsub(']', '\]')
        end
      end
    end

    def non_capture_group(args, **opts)
      non_capture_group, char_class = groups args

      if char_class.empty? && non_capture_group.size == 1
        non_capture_group.first
      else
        strings = non_capture_group.join '|'
        chars   = char_class.empty? ? '' : "[#{char_class.join}]|"
        head    = opts.fetch(:wrap, true) ? '(?:' : ''
        tail    = opts.fetch(:wrap, true) ? ')'   : ''

        "#{head}#{chars}#{strings}#{tail}"
      end
    end

    def character_class(args, **)
      pats   = map_patterns(*args)
      joined = pats.join
      if joined =~ /\A\\?.\z/i
        escape joined
      else
        joined = pats.map { |ptrn| ptrn.size == 1 ? character_class_escape(ptrn) : ptrn }.join
        "[#{joined}]"
      end
    end

    def map_pattern_symbols(*args)
      args.select(&Symbol.method(:===)).flat_map do |symbol|
        normalized = singularize symbol
        component  = MAPPING[normalized]

        next map_pattern_symbols(*component) if component.is_a? Array
        normalized if component
      end.compact.uniq
    end

    def map_patterns(*args)
      # create ranges from range character clause
      syms, rest = map_pattern_symbols(*args).each_with_object([[], []]) do |mapping, lists|
        if MAPPING[mapping].match(/\A.-.\z/)
          lists[0] << Range.new(*MAPPING[mapping].split('-'))
        elsif MAPPING[mapping]
          lists[1] << MAPPING[mapping]
        end
      end.compact

      # filter ranges that are sub-ranges of other ranges
      range_arys = syms.concat(args.select(&Range.method(:===))).map(&:to_a)
      range_arys = range_arys.reject do |range|
        (range_arys - [range]).any? { |other| (range - other).empty? }
      end

      # filter single-letter input strings that are already
      # present in a given range of characters
      flat         = range_arys.flatten.map(&:to_s)
      nums         = args.select { |a| a.is_a?(Numeric) || a =~ /\A\d\z/ }
                         .uniq.map(&:to_s)
                         .reject { |s| flat.include? s }
      chars        = args.select { |a| a.is_a?(String) && a !~ /\A\d\z/ }
      single_chars = chars.select { |s| s.size == 1 }
                          .reject { |char| flat.include? char }.uniq
      multi_chars  = chars.select { |s| s.size > 1 }.uniq

      # map everything back to character class groups in x-y format
      range_arys.map { |ary| "#{ary.first}-#{ary.last}" }
                .concat(single_chars).concat(multi_chars)
                .concat(nums).concat(rest)
    end

    def singularize(word)
      str = word.to_s.downcase
      str[0..(str.end_with?('s') ? -2 : -1)].to_sym
    end

    def flag_value
      @flags.reduce(0) do |val, flag|
        case flag.to_sym
        when :m then val | Regexp::MULTILINE
        when :i then val | Regexp::IGNORECASE
        when :x then val | Regexp::EXTENDED
        end
      end
    end

    def method_missing(method, *args, &block)
      return super unless Regexp.instance_methods.include? method

      regexp.send(method, *args, &block)
    end

    def respond_to_missing?(method, *)
      true if Regexp.instance_methods.include? method
    end

    def scoped(&block)
      original_str   = @str
      original_flags = @flags
      @str           = ''

      instance_eval(&block) if block_given?

      result_str = @str
      @str       = original_str
      @flags     = original_flags

      result_str
    end
  end
end

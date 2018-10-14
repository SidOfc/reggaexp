# frozen_string_literal: true
# Reggaexp main module
module Reggaexp
  # Reggaexp::Expression provides a more human friendly API
  # for users to create regular expressions with
  class Expression < Engine
    def initialize
      super
    end

    def case_insensitive
      add_flag :i
    end

    def case_sensitive
      remove_flag :i
    end

    def whitespace_insensitive
      add_flag :x
    end

    def whitespace_sensitive
      remove_flag :x
    end

    def multi_line
      add_flag :m
    end

    def single_line
      remove_flag :m
    end

    def start_of_line(*args)
      parse *args, prepend: '^'
    end

    def start_of_string(*args)
      parse *args, prepend: '\A'
    end

    def end_of_line(*args)
      parse *args, append:  '$'
    end

    def end_of_string(*args)
      parse *args, append: '\z'
    end

    def one_or_more(*args)
      parse *args, quantifier: '+'
    end

    def zero_or_more(*args)
      parse *args, quantifier: '*'
    end

    def zero_or_one(*args)
      parse *args, quantifier: '?'
    end

    def repeat(amount, *args)
      parse *args, quantifier: "{#{amount}}"
    end

    def between(rng_or_ary, *args)
      parse *args, quantifier: [rng_or_ary.first, rng_or_ary.last]
    end

    def at_least(amount, *args)
      parse *args, quantifier: [amount, nil]
    end

    def at_most(amount, *args)
      parse *args, quantifier: [nil, amount]
    end

    def group(*args, &block)
      parse *args, non_capture: true, &block
    end

    def not(*args)
      parse *args, non_capture: false, prepend: '(?!', append: ')'
    end

    def preceded_by(*args)
      parse *args, non_capture: false, prepend: '(?<=', append: ')'
    end

    def not_preceded_by(*args)
      parse *args, non_capture: false, prepend: '(?<!', append: ')'
    end

    def or(*args, &block)
      parse or: true # or

      if block_given?
        parse(&block)
      elsif args.any?
        parse(*args)
      end

      self
    end

    def find(maybe_count = nil, *args, &block)
      opts       = {}
      quantifier = maybe_count.is_a?(Numeric) ||
                   maybe_count.is_a?(Array)   ||
                   numeric_range?(maybe_count)

      if quantifier
        return repeat maybe_count.to_i, *args if maybe_count.is_a? Numeric

        between(maybe_count.minmax, *args)
      else
        args.unshift maybe_count unless maybe_count.nil?

        parse(*args.compact, &block)
      end
    end

    alias then find
  end
end

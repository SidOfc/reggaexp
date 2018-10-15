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

    def start_of_line(*args, &block)
      parse(*args, prepend: '^', &block)
    end

    def start_of_string(*args, &block)
      parse(*args, prepend: '\A', &block)
    end

    def end_of_line(*args, &block)
      parse(*args, append:  '$', &block)
    end

    def end_of_string(*args, &block)
      parse(*args, append: '\z', &block)
    end

    def one_or_more(*args, &block)
      parse(*args, quantifier: '+', &block)
    end
    alias at_least_one one_or_more

    def zero_or_more(*args, &block)
      parse(*args, quantifier: '*', &block)
    end
    alias maybe_multiple zero_or_more

    def zero_or_one(*args, &block)
      parse(*args, quantifier: '?', &block)
    end
    alias maybe zero_or_one

    def repeat(amount, *args, &block)
      parse(*args, quantifier: "{#{amount}}", &block)
    end

    def times(amount, &block)
      parse quantifier: "{#{amount}}", &block
    end

    def between(rng_or_ary, *args, &block)
      parse(*args, quantifier: [rng_or_ary.first, rng_or_ary.last], &block)
    end

    def at_least(amount, *args, &block)
      parse(*args, quantifier: [amount, nil], &block)
    end
    alias min at_least

    def at_most(amount, *args, &block)
      parse(*args, quantifier: [nil, amount], &block)
    end
    alias max at_most

    def group(*args, &block)
      parse(*args, non_capture: true, &block)
    end

    def capture(*args, **opts, &block)
      parse(*args, opts.merge(capture: true), &block)
    end

    def not(*args, &block)
      parse(*args, non_capture: false, prepend: '(?!', append: ')', &block)
    end

    def preceded_by(*args, &block)
      parse(*args, non_capture: false, prepend: '(?<=', append: ')', &block)
    end

    def not_preceded_by(*args, &block)
      parse(*args, non_capture: false, prepend: '(?<!', append: ')', &block)
    end

    def or(*args, &block)
      parse or: true
      parse(*args, &block) if args.any? || block_given?

      self
    end

    def find(maybe_count = nil, *args, &block)
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
    alias then   find
    alias one_of find
  end
end

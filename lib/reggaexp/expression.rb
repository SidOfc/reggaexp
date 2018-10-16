# frozen_string_literal: true

# Reggaexp main module
module Reggaexp
  # Reggaexp::Expression provides a more human friendly API
  # for users to create regular expressions with
  class Expression < Engine
    def find(maybe_count = nil, *args, **opts, &block)
      quantifier = maybe_count.is_a?(Numeric) ||
                   maybe_count.is_a?(Array)   ||
                   numeric_range?(maybe_count)

      if quantifier
        return repeat(maybe_count.to_i, *args, **opts) if maybe_count.is_a? Numeric

        between(maybe_count.minmax, *args, **opts)
      else
        args.unshift maybe_count unless maybe_count.nil?

        parse(*args, **opts, &block)
      end
    end
    alias then   find
    alias one_of find

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

    def start_of_line(*args, **opts, &block)
      find(*args, **opts.merge(prepend: '^'), &block)
    end

    def start_of_string(*args, **opts, &block)
      find(*args, **opts.merge(prepend: '\A'), &block)
    end

    def end_of_line(*args, **opts, &block)
      find(*args, **opts.merge(append: '$'), &block)
    end

    def end_of_string(*args, **opts, &block)
      find(*args, **opts.merge(append: '\z'), &block)
    end

    def one_or_more(*args, **opts, &block)
      find(*args, **opts.merge(quantifier: '+'), &block)
    end
    alias at_least_one one_or_more

    def zero_or_more(*args, **opts, &block)
      find(*args, **opts.merge(quantifier: '*'), &block)
    end
    alias maybe_multiple zero_or_more

    def zero_or_one(*args, **opts, &block)
      find(*args, **opts.merge(quantifier: '?'), &block)
    end
    alias maybe zero_or_one

    def repeat(amount, *args, **opts, &block)
      find(*args, **opts.merge(quantifier: "{#{amount}}"), &block)
    end

    def between(rng_or_ary, *args, **opts, &block)
      find(*args, **opts.merge(quantifier: [rng_or_ary.first, rng_or_ary.last]),
           &block)
    end

    def at_least(amount, *args, **opts, &block)
      find(*args, **opts.merge(quantifier: [amount, nil]), &block)
    end
    alias min at_least

    def at_most(amount, *args, **opts, &block)
      find(*args, **opts.merge(quantifier: [nil, amount]), &block)
    end
    alias max at_most

    def group(*args, **opts, &block)
      non_capture = true unless opts.key?(:as) || opts[:capture]
      find(*args, **opts.merge(non_capture: non_capture), &block)
    end

    def capture(*args, **opts, &block)
      find(*args, opts.merge(capture: true), &block)
    end

    def not(*args, **opts, &block)
      find(*args, **opts.merge(non_capture: false, capture: false, as: nil,
                               prepend: '(?!', append: ')'), &block)
    end

    def is(*args, **opts, &block)
      find(*args, **opts.merge(non_capture: false, capture: false, as: nil,
                               prepend: '(?=', append: ')'), &block)
    end

    def preceded_by(*args, **opts, &block)
      find(*args, **opts.merge(non_capture: false, capture: false, as: nil,
                               prepend: '(?<=', append: ')'), &block)
    end
    alias prev preceded_by

    def not_preceded_by(*args, **opts, &block)
      find(*args, **opts.merge(non_capture: false, capture: false, as: nil,
                               prepend: '(?<!', append: ')'), &block)
    end
    alias not_prev not_preceded_by

    def or(*args, **opts, &block)
      opts.delete :or
      find or: true
      find(*args, **opts, &block) if args.any? || block_given?

      self
    end
  end
end

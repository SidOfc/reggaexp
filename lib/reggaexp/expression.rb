# frozen_string_literal: true

# Reggaexp main module
module Reggaexp
  # Reggaexp::Expression provides a more human friendly API
  # for users to create regular expressions with
  class Expression < Engine
    def find(maybe_count = nil, *args, **opts, &block)
      if arg_is_count? maybe_count
        return repeat(maybe_count, *args, **opts, &block) if maybe_count.is_a? Numeric
        between([maybe_count.first, maybe_count.last], *args, **opts, &block)
      else
        args.unshift maybe_count unless maybe_count.nil?

        parse(*args, **opts, &block)
      end
    end
    alias then   find
    alias one_of find
    alias any_of find

    def arg_is_count?(arg)
      arg.is_a?(Numeric) ||
        arg.is_a?(Array) ||
        numeric_range?(arg)
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

    def start_to_end_of_line(*args, **opts, &block)
      find(*args, **opts.merge(prepend: '^', append: '$'), &block)
    end

    def start_to_end_of_string(*args, **opts, &block)
      find(*args, **opts.merge(prepend: '\A', append: '\z'), &block)
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

    def group_atoms_before_action?(*args, &block)
      block ||
        arg_is_count?(args[0]) ||
        exprs_from_atoms({content: unify_atoms(with_presets(args))}).size > 1
    end

    def one_or_more(*args, **opts, &block)
      return group(*args, **opts.merge(append: '+'), &block) if group_atoms_before_action?(*args, &block)

      find(*args, **opts.merge(quantifier: '+'), &block)
    end
    alias at_least_one one_or_more

    def zero_or_more(*args, **opts, &block)
      return group(*args, **opts.merge(append: '*'), &block) if group_atoms_before_action?(*args, &block)

      find(*args, **opts.merge(quantifier: '*'), &block)
    end
    alias maybe_multiple zero_or_more

    def zero_or_one(*args, **opts, &block)
      return group(*args, **opts.merge(append: '?'), &block) if group_atoms_before_action?(*args, &block)

      find(*args, **opts.merge(quantifier: '?'), &block)
    end
    alias maybe zero_or_one

    def repeat(amount, *args, **opts, &block)
      return group(*args, **opts.merge(append: "{#{amount}}"), &block) if group_atoms_before_action?(*args, &block)

      find(*args, **opts.merge(quantifier: "{#{amount}}"), &block)
    end

    def between(rng_or_ary, *args, **opts, &block)
      return group(*args, **opts, &block).between(rng_or_ary) if group_atoms_before_action?(*args, &block)

      find(*args, **opts.merge(quantifier: [rng_or_ary.first, rng_or_ary.last]),
           &block)
    end

    def at_least(amount, *args, **opts, &block)
      return group(*args, **opts, &block).at_least(amount) if group_atoms_before_action?(*args, &block)

      find(*args, **opts.merge(quantifier: [amount, nil]), &block)
    end
    alias min at_least

    def at_most(amount, *args, **opts, &block)
      return group(*args, **opts, &block).at_most(amount) if group_atoms_before_action?(*args, &block)

      find(*args, **opts.merge(quantifier: [nil, amount]), &block)
    end
    alias max at_most

    def group(*args, **opts, &block)
      non_capture = true unless opts.key?(:as) || opts[:capture]
      find(*args, **opts.merge(non_capture: non_capture), &block)
    end

    def capture(*args, **opts, &block)
      find(*args, **opts.merge(capture: true), &block)
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

# frozen_string_literal: true
# Reggaexp main module
module Reggaexp
  # Reggaexp::Expression provides a more human friendly API
  # for users to create regular expressions with
  class Expression < Engine
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

    def between(rng_or_ary, *args)
      parse *args, quantifier: [rng_or_ary.first, rng_or_ary.last]
    end

    def at_least(amount, *args)
      parse *args, quantifier: [amount, nil]
    end

    def at_most(amount, *args)
      parse *args, quantifier: [nil, amount]
    end
  end
end

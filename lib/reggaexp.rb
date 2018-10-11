# frozen_string_literal: true

require 'reggaexp/version'
require 'reggaexp/base'
require 'reggaexp/v2/base'

# Reggaexp main module
module Reggaexp
  def self.method_missing(method, *args, &block)
    Expression.new.send method, *args, &block
  end

  def self.respond_to_missing?(*)
    true
  end

  # Reggaexp::Expression builds regular expressions using method chaining style
  class Expression < Base
    def case_insensitive
      add_flag :i
    end

    def case_sensitive
      remove_flag :i
    end

    def whitespace_insensitive
      add_flag :x
    end
    alias extended whitespace_insensitive

    def whitespace_sensitive
      remove_flag :x
    end
    alias not_extended whitespace_sensitive

    def multi_line
      add_flag :m
    end

    def single_line
      remove_flag :m
    end

    def start_with(*args)
      write '^%s', *args, prepend: true
    end
    alias start_of_line   start_with
    alias line_start_with start_with

    def string_start_with(*args)
      write '\A%s', *args, prepend: true
    end
    alias start_of_string string_start_with

    def end_with(*args)
      write '%s$', *args
    end
    alias end_of_line   end_with
    alias line_end_with end_with

    def string_end_with(*args)
      write '%s\z', *args
    end
    alias end_of_string string_end_with

    def between(min, max, *args)
      write '%s', [min, max], *args
    end

    def at_least(amount, *args)
      write '%s', [amount, nil], *args
    end

    def at_most(amount, *args)
      write '%s', [nil, amount], *args
    end

    def repeat(*args)
      write '{%s}', *args
    end

    def zero_or_more(*args)
      write '%s*', *args
    end

    def one_or_more(*args)
      write '%s+', *args
    end

    def zero_or_one(*args)
      write '%s?', *args
    end
    alias optional zero_or_more
    alias maybe    zero_or_more

    def find(*args)
      write '%s', *args
    end
    alias then   find
    alias and    find
    alias one_of find

    def or(*args, &block)
      write '|%s', *args, &block
    end

    def not(*args)
      write '(?!%s)', *args, wrap: false
    end

    def not_preceded_by(*args)
      write '(?<!%s)', *args, wrap: false
    end

    def preceded_by(*args)
      write '(?<=%s)', *args, wrap: false
    end

    def non_capture(*args, &block)
      write '(?:%s)', *args, wrap: false, &block
    end
    alias group non_capture

    def capture(*args, **opts, &block)
      atom = '(%s)'
      atom = "(?<#{opts[:as]}>%s)" if opts.key? :as

      write atom, *args, wrap: false, &block
    end
  end
end

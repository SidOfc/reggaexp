# frozen_string_literal: true

require 'reggaexp/version'
require 'reggaexp/engine'
require 'reggaexp/expression'

# Reggaexp main module
module Reggaexp
  def self.method_missing(method, *args, &block)
    Expression.new.send method, *args, &block
  end

  def self.respond_to_missing?(*)
    true
  end
end

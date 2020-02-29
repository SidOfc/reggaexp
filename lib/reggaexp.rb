# frozen_string_literal: true

require 'reggaexp/version'
require 'reggaexp/presets'
require 'reggaexp/engine'
require 'reggaexp/expression'

# Reggaexp main module
module Reggaexp
  def self.method_missing(method, *args, **opts, &block)
    Expression.new.send method, *args, **opts, &block
  end

  def self.respond_to_missing?(*)
    true
  end
end

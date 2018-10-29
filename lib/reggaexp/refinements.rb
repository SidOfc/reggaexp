# frozen_string_literal: true

# Reggaexp main module
module Reggaexp
  # Refine Integer to do things like 2.letters
  # instead of find(2, :letters)
  module Refinements
    refine ::Integer do
      PRESET_KEYS.each do |mtd|
        define_method(mtd) { Reggaexp::Expression.new.find(self, mtd) }
      end
    end
  end
end

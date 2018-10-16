require 'bundler/setup'
require 'reggaexp'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# print expected regular expression result
# instead of entire class
module Reggaexp
  class Engine
    def inspect
      pattern.inspect
    end
  end
end

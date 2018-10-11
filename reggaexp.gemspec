# frozen_string_literal: true

lib = File.expand_path 'lib', __dir__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
require 'reggaexp/version'

Gem::Specification.new do |spec|
  spec.name          = 'reggaexp'
  spec.version       = Reggaexp.version
  spec.authors       = ['Sidney Liebrand']
  spec.email         = ['sidneyliebrand@gmail.com']

  spec.summary       = 'A DSL that makes writing regular expressions easy'
  spec.homepage      = 'https://github.com/SidOfc/reggaexp'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been
  # added into git.
  spec.files         = Dir.chdir File.expand_path(__dir__) do
    `git ls-files -z`.split("\x0")
                     .reject { |f| f.match %r{^ test|spec|features/} }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}, &File.method(:basename))
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end

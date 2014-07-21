# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jasmine/flatiron/version'

Gem::Specification.new do |spec|
  spec.name          = "jasmine-flatiron"
  spec.version       = Jasmine::Flatiron::VERSION
  spec.authors       = ["Logan Hasson", "Adam Jonas"]
  spec.email         = ["logan.hasson@gmail.com"]
  spec.summary       = %q{Flatiron School Jasmine spec suite runner}
  spec.homepage      = "http://github.com/flatiron-school/jasmine-flatiron"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib", "bin"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency "faraday", "~> 0.9"
  spec.add_runtime_dependency "crack"
  spec.add_runtime_dependency "netrc"
  spec.add_runtime_dependency "git"
  spec.add_runtime_dependency "awesome_print"
end

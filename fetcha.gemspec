# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fetcha/version'

Gem::Specification.new do |spec|
  spec.name          = "fetcha"
  spec.version       = Fetcha::VERSION
  spec.authors       = ["Vincenzo Ferrara"]
  spec.email         = ["vinceferro92@gmail.com"]

  spec.summary       = %q{Enable api to respond to jsonapi query string}
  spec.homepage      = "https://github.com/vinceferro/fetcha"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency("activesupport", ">= 3.0.0")
  spec.add_dependency("pg_search")
  
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

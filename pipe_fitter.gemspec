# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pipe_fitter/version'

Gem::Specification.new do |spec|
  spec.name          = "pipe_fitter"
  spec.version       = PipeFitter::VERSION
  spec.authors       = ["masa21kik"]
  spec.email         = ["masa21kik@gmail.com"]

  spec.summary       = %q{PipeFitter is a tool for AWS Data Pipeline.}
  spec.description   = %q{PipeFitter is a tool for AWS Data Pipeline.}
  spec.homepage      = "https://github.com/masa21kik/pipe_fitter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "aws-sdk", "~> 2"
  spec.add_runtime_dependency "diffy"
  spec.add_runtime_dependency "thor"
  spec.add_runtime_dependency "hashie"
  spec.add_runtime_dependency "s3diff"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "test-unit"
  spec.add_development_dependency "test-unit-rr"
  spec.add_development_dependency "pry-byebug"
end

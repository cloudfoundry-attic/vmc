# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "vmc/version"

Gem::Specification.new do |s|
  s.name        = "vmc-specs"
  s.version     = VMC::VERSION
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://github.com/cloudfoundry/vmc"
  s.summary     = %q{
    VMC client testing framework.
  }

  s.files         = %w{LICENSE} + Dir.glob("lib/vmc/spec_helpers{.rb,/**/*}")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "vmc", "~> 0.4.0.beta.30"
  s.add_runtime_dependency "rspec", "~> 2.11.0"
  s.add_runtime_dependency "simplecov", "~> 0.6.4"

  s.add_development_dependency "rake", "~> 0.9.2.2"
end

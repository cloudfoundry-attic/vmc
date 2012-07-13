# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "vmc/version"

Gem::Specification.new do |s|
  s.name        = "vmc"
  s.version     = VMC::VERSION
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://cloudfoundry.com/"
  s.summary     = %q{
    Friendly command-line interface for Cloud Foundry.
  }
  s.executables = %w{vmc}

  s.rubyforge_project = "vmc"

  s.files         = %w{LICENSE Rakefile} + Dir.glob("{lib,plugins}/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "json_pure", "~> 1.6.5"
  s.add_runtime_dependency "interact", "~> 0.4.1"
  s.add_runtime_dependency "cfoundry", "~> 0.3.2"
  s.add_runtime_dependency "mothership", "~> 0.0.1"
  s.add_runtime_dependency "manifests-vmc-plugin", "~> 0.3.1"
end

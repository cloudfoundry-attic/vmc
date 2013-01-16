# -*- encoding: utf-8 -*-

#############
# WARNING: Separate from the Gemfile. Please update both files
#############

$:.push File.expand_path("../lib", __FILE__)
require "vmc/version"

Gem::Specification.new do |s|
  s.name        = "vmc"
  s.version     = VMC::VERSION.dup
  s.authors     = ["Cloud Foundry Team", "Alex Suraci"]
  s.email       = %w(vcap-dev@googlegroups.com)
  s.homepage    = "http://github.com/cloudfoundry/vmc"
  s.summary     = %q{
    Friendly command-line interface for Cloud Foundry.
  }
  s.executables = %w{vmc}

  s.rubyforge_project = "vmc"

  s.files         = %w(LICENSE Rakefile) + Dir["lib/**/*"]
  s.test_files    = Dir["spec/**/*"]
  s.require_paths = %w(lib)

  s.add_runtime_dependency "json_pure", "~> 1.6"
  s.add_runtime_dependency "multi_json", "~> 1.3"

  s.add_runtime_dependency "interact", "~> 0.5.0"
  s.add_runtime_dependency "cfoundry", "~> 0.4.19"
  s.add_runtime_dependency "clouseau", "~> 0.0.2"
  s.add_runtime_dependency "mothership", "~> 0.5.0"
  s.add_runtime_dependency "manifests-vmc-plugin", "~> 0.5.0"
  s.add_runtime_dependency "tunnel-vmc-plugin", "~> 0.1.11"

  s.add_development_dependency "rake", "~> 0.9"
  s.add_development_dependency "rspec", "~> 2.11"
  s.add_development_dependency "webmock", "~> 1.9"
  s.add_development_dependency "rr", "~> 1.0"
end

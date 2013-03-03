SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "cfoundry/test_support"
require "vmc"
require "vmc/test_support"
require "webmock"
require "ostruct"

INTEGRATE_WITH = ENV["INTEGRATE_WITH"] || "default"

def vmc_bin
  vmc = File.expand_path("#{SPEC_ROOT}/../bin/vmc.dev")
  if INTEGRATE_WITH != 'default'
    "rvm #{INTEGRATE_WITH}@vmc do #{vmc}"
  else
    vmc
  end
end

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each do |file|
  require file
end

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.include V1Fake::FakeMethods
  c.include ConsoleAppSpeckerMatchers

  c.mock_with :rr

  if RUBY_VERSION =~ /^1\.8\.\d/
    c.filter_run_excluding :ruby19 => true
  end

  c.include FakeHomeDir
  c.include CommandHelper
  c.include InteractHelper
  c.include ConfigHelper

  c.before(:all) do
    WebMock.disable_net_connect!
  end

  c.before do
    VMC::CLI.send(:class_variable_set, :@@client, nil)
  end
end

def name_list(xs)
  if xs.empty?
    "none"
  else
    xs.collect(&:name).join(", ")
  end
end

def run(command)
  SpeckerRunner.new(command) do |runner|
    yield runner
  end
end

SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "cfoundry/test_support"
require "vmc"
require "vmc/test_support"

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each do |file|
  require file
end

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.mock_with :rr

  c.include VMC::TestSupport::FakeHomeDir
  c.include VMC::TestSupport::CommandHelper
end

class String
  def strip_heredoc
    min = scan(/^[ \t]*(?=\S)/).min
    indent = min ? min.size : 0
    gsub(/^[ \t]{#{indent}}/, '')
  end

  def strip_progress_dots
    gsub(/\.  \x08([\x08\. ]+)/, "... ")
  end
end

def name_list(xs)
  if xs.empty?
    "none"
  else
    xs.collect(&:name).join(", ")
  end
end

def invoke_cli(cli, *args)
  stub.proxy(cli).invoke.with_any_args
  stub(cli.class).new { cli }
  cli.invoke(*args)
end

def stub_output(cli)
  stub(cli).print
  stub(cli).puts
  stub(Interact::Progress::Dots).start!
  stub(Interact::Progress::Dots).stop!
end

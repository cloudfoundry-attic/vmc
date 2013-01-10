SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "cfoundry/test_support"
require "vmc"

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each do |file|
  require file
end

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.mock_with :rr
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

def with_output_to(output = StringIO.new)
  old_out = $stdout
  old_err = $stderr
  $stdout = output
  $stderr = output
  yield output
ensure
  $stdout = old_out
  $stderr = old_err
end

def name_list(xs)
  if xs.empty?
    "none"
  else
    xs.collect(&:name).join(", ")
  end
end

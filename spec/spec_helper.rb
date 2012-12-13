SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "vmc"
require 'factory_girl'
require 'webmock/rspec'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each do |file|
  require file
end

FactoryGirl.find_definitions

RSpec.configure do |c|
  c.mock_with :rr
end

class String
  def strip_heredoc
    min = scan(/^[ \t]*(?=\S)/).min
    indent = min ? min.size : 0
    gsub(/^[ \t]{#{indent}}/, '')
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
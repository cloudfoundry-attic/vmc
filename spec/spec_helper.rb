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


def reassign_stdout_to(output)
  old_out = $stdout
  $stdout = output
  yield $stdout
ensure
  $stdout = old_out
end

def name_list(xs)
  if xs.empty?
    "none"
  else
    xs.collect(&:name).join(", ")
  end
end
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


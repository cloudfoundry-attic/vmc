require "vmc/spec_helpers"
require "simplecov"

SimpleCov.start do
  root File.expand_path("../../", __FILE__)
  add_filter "spec/"
end

require "vmc/version"

require "vmc/cli"
require "vmc/cli/start"
require "vmc/cli/service"
require "vmc/cli/user"
require "vmc/cli/space"

Dir[File.expand_path("../vmc/cli/{app,route,domain,organization}/*.rb", __FILE__)].each do |file|
  require file unless File.basename(file) == 'base.rb'
end

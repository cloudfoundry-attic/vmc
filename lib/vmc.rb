require "vmc/version"

require "vmc/cli"

command_files = "../vmc/cli/{app,route,domain,organization,space,service,start,user}/*.rb"
Dir[File.expand_path(command_files, __FILE__)].each do |file|
  require file unless File.basename(file) == 'base.rb'
end

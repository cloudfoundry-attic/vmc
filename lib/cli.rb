ROOT = File.expand_path(File.dirname(__FILE__))
WINDOWS = !!(RUBY_PLATFORM =~ /mingw|mswin32|cygwin/)


module VMC
  autoload :Client,           "#{ROOT}/vmc/client"

  module Cli
    autoload :Config,         "#{ROOT}/cli/config"
    autoload :Framework,      "#{ROOT}/cli/frameworks"
    autoload :Runner,         "#{ROOT}/cli/runner"
    autoload :ZipUtil,        "#{ROOT}/cli/zip_util"
    autoload :ServicesHelper, "#{ROOT}/cli/services_helper"

    module Command
      autoload :Base,         "#{ROOT}/cli/commands/base"
      autoload :Admin,        "#{ROOT}/cli/commands/admin"
      autoload :Apps,         "#{ROOT}/cli/commands/apps"
      autoload :Misc,         "#{ROOT}/cli/commands/misc"
      autoload :Services,     "#{ROOT}/cli/commands/services"
      autoload :User,         "#{ROOT}/cli/commands/user"
    end

  end
end

require "#{ROOT}/cli/version"
require "#{ROOT}/cli/core_ext"
require "#{ROOT}/cli/errors"

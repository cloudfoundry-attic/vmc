require "rbconfig"

ROOT = File.expand_path(File.dirname(__FILE__))
WINDOWS = !!(RbConfig::CONFIG['host_os'] =~ /mingw|mswin32|cygwin/)

module VMC
  autoload :Client,           "#{ROOT}/vmc/client"
  autoload :Micro,            "#{ROOT}/vmc/micro"

  module Micro
    module Switcher
      autoload :Base,         "#{ROOT}/vmc/micro/switcher/base"
      autoload :Darwin,       "#{ROOT}/vmc/micro/switcher/darwin"
      autoload :Dummy,        "#{ROOT}/vmc/micro/switcher/dummy"
      autoload :Linux,        "#{ROOT}/vmc/micro/switcher/linux"
      autoload :Windows,      "#{ROOT}/vmc/micro/switcher/windows"
    end
    autoload :VMrun,          "#{ROOT}/vmc/micro/vmrun"
  end

  module Cli
    autoload :Config,         "#{ROOT}/cli/config"
    autoload :Framework,      "#{ROOT}/cli/frameworks"
    autoload :Runner,         "#{ROOT}/cli/runner"
    autoload :ZipUtil,        "#{ROOT}/cli/zip_util"
    autoload :ServicesHelper, "#{ROOT}/cli/services_helper"
    autoload :TunnelHelper,   "#{ROOT}/cli/tunnel_helper"
    autoload :ManifestHelper, "#{ROOT}/cli/manifest_helper"
    autoload :ConsoleHelper,  "#{ROOT}/cli/console_helper"

    module Command
      autoload :Base,         "#{ROOT}/cli/commands/base"
      autoload :Admin,        "#{ROOT}/cli/commands/admin"
      autoload :Apps,         "#{ROOT}/cli/commands/apps"
      autoload :Micro,        "#{ROOT}/cli/commands/micro"
      autoload :Misc,         "#{ROOT}/cli/commands/misc"
      autoload :Services,     "#{ROOT}/cli/commands/services"
      autoload :User,         "#{ROOT}/cli/commands/user"
      autoload :Manifest,     "#{ROOT}/cli/commands/manifest"
    end

  end
end

require "#{ROOT}/cli/version"
require "#{ROOT}/cli/core_ext"
require "#{ROOT}/cli/errors"

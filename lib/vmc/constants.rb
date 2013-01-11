module VMC
  OLD_TARGET_FILE = "~/.vmc_target".freeze
  OLD_TOKENS_FILE = "~/.vmc_token".freeze

  CONFIG_DIR = "~/.vmc".freeze

  LOGS_DIR = "#{CONFIG_DIR}/logs".freeze
  PLUGINS_FILE = "#{CONFIG_DIR}/plugins.yml".freeze
  TARGET_FILE = "#{CONFIG_DIR}/target".freeze
  TOKENS_FILE = "#{CONFIG_DIR}/tokens.yml".freeze
  COLORS_FILE = "#{CONFIG_DIR}/colors.yml".freeze
  CRASH_FILE = "#{CONFIG_DIR}/crash".freeze
end

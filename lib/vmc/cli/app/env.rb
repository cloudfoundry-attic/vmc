require "vmc/cli/app/base"

module VMC::App
  class Env < Base
    VALID_ENV_VAR = /^[a-zA-Za-z_][[:alnum:]_]*$/

    desc "Show all environment variables set for an app"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the environment of",
      :from_given => by_name("app")
    def env
      app = input[:app]

      vars =
        with_progress("Getting env for #{c(app.name, :name)}") do |s|
          app.env
        end

      line unless quiet?

      vars.each do |name, val|
        line "#{c(name, :name)}: #{val}"
      end
    end

    desc "Set an environment variable"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to set the variable for",
      :from_given => by_name("app")
    input :name, :argument => true,
      :desc => "Environment variable name"
    input :value, :argument => :optional,
      :desc => "Environment variable value"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def set_env
      app = input[:app]
      name = input[:name]

      if value = input[:value]
        name = input[:name]
      elsif name["="]
        name, value = name.split("=")
      end

      unless name =~ VALID_ENV_VAR
        fail "Invalid variable name; must match #{VALID_ENV_VAR.inspect}"
      end

      with_progress("Updating #{c(app.name, :name)}") do
        app.env[name] = value
        app.update!
      end

      if app.started? && input[:restart]
        invoke :restart, :app => app
      end
    end


    desc "Remove an environment variable"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to set the variable for",
      :from_given => by_name("app")
    input :name, :argument => true,
      :desc => "Environment variable name"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def unset_env
      app = input[:app]
      name = input[:name]

      with_progress("Updating #{c(app.name, :name)}") do
        app.env.delete(name)
        app.update!
      end

      if app.started? && input[:restart]
        invoke :restart, :app => app
      end
    end
  end
end

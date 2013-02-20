require "vmc/cli/start/base"
require "vmc/cli/start/target_interactions"

module VMC::Start
  class Login < Base
    def precondition
      check_target
    end

    desc "Authenticate with the target"
    group :start
    input :username, :value => :email, :desc => "Account email",
          :alias => "--email", :argument => :optional
    input :password, :desc => "Account password"
    input :organization, :desc => "Organization" , :aliases => %w{--org -o},
          :from_given => by_name(:organization)
    input :space, :desc => "Space", :alias => "-s",
          :from_given => by_name(:space)
    interactions TargetInteractions
    def login
      show_context

      credentials =
        { :username => input[:username],
          :password => input[:password]
        }

      prompts = client.login_prompts

      # ask username first
      if prompts.key? :username
        type, label = prompts.delete :username
        credentials[:username] ||= ask_prompt(type, label)
      end

      info = target_info

      auth_token = nil
      authenticated = false
      failed = false
      remaining_attempts = 3
      until authenticated || remaining_attempts <= 0
        remaining_attempts -= 1
        unless force?
          ask_prompts(credentials, prompts)
        end

        with_progress("Authenticating") do |s|
          begin
            auth_token = client.login(credentials[:username], credentials[:password])
            authenticated = true
          rescue CFoundry::Denied
            return if force?

            s.fail do
              failed = true
              credentials.delete(:password)
            end
          end
        end
      end

      info.merge!(auth_token.to_hash)
      save_target_info(info)
      invalidate_client

      if v2?
        line if input.interactive?(:organization) || input.interactive?(:space)
        select_org_and_space(input, info)
      end

      save_target_info(info)
    ensure
      exit_status 1 if not authenticated
    end

    private

    def ask_prompts(credentials, prompts)
      prompts.each do |name, meta|
        type, label = meta
        credentials[name] ||= ask_prompt(type, label)
      end
    end

    def ask_prompt(type, label)
      if type == "password"
        options = { :echo => "*", :forget => true }
      else
        options = {}
      end

      ask(label, options)
    end
  end
end

module VMC::Cli::Command

  class Admin < Base

    def list_users
      users = client.users
      users.sort! {|a, b| a[:email] <=> b[:email] }
      return display JSON.pretty_generate(users || []) if @options[:json]

      display "\n"
      return display "No Users" if users.nil? || users.empty?

      users_table = table do |t|
        t.headings = 'Email', 'Admin', 'Apps'
        users.each do |user|
          t << [user[:email], user[:admin], user[:apps].map {|x| x[:name]}.join(', ')]
        end
      end
      display users_table
    end

    alias :users :list_users

    def add_user(email=nil)
      email ||= @options[:email]
      email ||= ask("Email") unless no_prompt
      password = @options[:password]
      unless no_prompt || password
        password = ask("Password", :echo => "*")
        password2 = ask("Verify Password", :echo => "*")
        err "Passwords did not match, try again" if password != password2
      end
      err "Need a valid email" unless email
      err "Need a password" unless password
      display 'Creating New User: ', false
      client.add_user(email, password)
      display 'OK'.green

      # if we are not logged in for the current target, log in as the new user
      return unless VMC::Cli::Config.auth_token.nil?
      @options[:password] = password
      cmd = User.new(@options)
      cmd.login(email)
    end

    def delete_user(user_email)
      # Check to make sure all apps and services are deleted before deleting the user
      # implicit proxying

      client.proxy_for(user_email)
      @options[:proxy] = user_email
      apps = client.apps

      if (apps && !apps.empty?)
        unless no_prompt
          proceed = ask(
            "\nDeployed applications and associated services will be DELETED, continue?",
            :default => false
          )
          err "Aborted" unless proceed
        end
        cmd = Apps.new(@options.merge({ :force => true }))
        apps.each { |app| cmd.delete(app[:name]) }
      end

      services = client.services
      if (services && !services.empty?)
        cmd = Services.new(@options)
        services.each { |s| cmd.delete_service(s[:name])}
      end

      display 'Deleting User: ', false
      client.proxy = nil
      client.delete_user(user_email)
      display 'OK'.green
    end

  end

end

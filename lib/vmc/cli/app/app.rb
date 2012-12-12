require "vmc/cli/app/base"

module VMC::App
  class Apps < Base
    IS_UTF8 = !!(ENV["LC_ALL"] || ENV["LC_CTYPE"] || ENV["LANG"] || "")["UTF-8"].freeze

    desc "Show app information"
    group :apps
    input :app, :desc => "App to show", :argument => :required,
          :from_given => by_name(:app)
    def app
      app = input[:app]

      if quiet?
        line app.name
      else
        display_app(app)
      end
    end

    def display_app(a)
      status = app_status(a)

      line "#{c(a.name, :name)}: #{status}"

      indented do
        line "platform: #{b(a.framework.name)} on #{b(a.runtime.name)}"

        start_line "usage: #{b(human_mb(a.memory))}"
        print " #{d(IS_UTF8 ? "\xc3\x97" : "x")} #{b(a.total_instances)}"
        print " instance#{a.total_instances == 1 ? "" : "s"}"

        line

        unless a.urls.empty?
          line "urls: #{a.urls.collect { |u| b(u) }.join(", ")}"
        end

        unless a.services.empty?
          line "services: #{a.services.collect { |s| b(s.name) }.join(", ")}"
        end
      end
    end
  end
end

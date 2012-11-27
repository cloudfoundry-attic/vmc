require "vmc/cli/app/base"

module VMC::App
  class File < Base
    desc "Print out an app's file contents"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the files of",
      :from_given => by_name("app")
    input :path, :argument => true, :default => "/",
      :desc => "Path of file to read"
    def file
      app = input[:app]
      path = input[:path]

      file =
        with_progress("Getting file contents") do
          app.file(*path.split("/"))
        end

      if quiet?
        print file
      else
        line

        file.split("\n").each do |l|
          line l
        end
      end
    rescue CFoundry::NotFound
      fail "Invalid path #{b(path)} for app #{b(app.name)}"
    rescue CFoundry::FileError => e
      fail e.description
    end

    desc "Examine an app's files"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the files of",
      :from_given => by_name("app")
    input :path, :argument => :optional, :default => "/",
      :desc => "Path of directory to list"
    def files
      app = input[:app]
      path = input[:path]

      if quiet?
        files =
          with_progress("Getting file listing") do
            app.files(*path.split("/"))
          end

        files.each do |file|
          line file.join("/")
        end
      else
        invoke :file, :app => app, :path => path
      end
    rescue CFoundry::NotFound
      fail "Invalid path #{b(path)} for app #{b(app.name)}"
    rescue CFoundry::FileError => e
      fail e.description
    end

    desc "Stream an app's file contents"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the file of",
      :from_given => by_name("app")
    input :path, :argument => true, :default => "/",
      :desc => "Path of file to stream"
    def tail
      app = input[:app]
      path = input[:path]

      app.stream_file(*path.split("/")) do |contents|
        print contents
      end
    rescue CFoundry::NotFound
      fail "Invalid path #{b(path)} for app #{b(app.name)}"
    rescue CFoundry::FileError => e
      fail e.description
    end
  end
end

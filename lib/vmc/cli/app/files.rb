require "thread"
require "vmc/cli/app/base"

module VMC::App
  class Files < Base
    desc "Print out an app's file contents"
    group :apps, :info, :hidden => true
    input :app, :desc => "Application to inspect the files of",
          :argument => true, :from_given => by_name(:app)
    input :path, :desc => "Path of file to read", :argument => :optional,
          :default => "/"
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
    input :app, :desc => "Application to inspect the files of",
          :argument => true, :from_given => by_name(:app)
    input :path, :desc => "Path of directory to list", :argument => :optional,
          :default => "/"
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
    input :app, :desc => "Application to inspect the files of",
          :argument => true, :from_given => by_name(:app)
    input :path, :desc => "Path of file to stream", :argument => :optional
    def tail
      app = input[:app]

      lines = Queue.new
      max_len = 0

      if path = input[:path]
        max_len = path.size
        app.instances.each do |i|
          Thread.new do
            stream_path(lines, i, path.split("/"))
          end
        end
      else
        app.instances.each do |i|
          i.files("logs").each do |path|
            len = path.join("/").size
            max_len = len if len > max_len

            Thread.new do
              stream_path(lines, i, path)
            end
          end
        end
      end

      while line = lines.pop
        instance, path, log = line

        unless log.end_with?("\n")
          log += i("%") if color?
          log += "\n"
        end

        print "\##{c(instance.id, :instance)}  "
        print "#{c(path.join("/").ljust(max_len), :name)}  "
        print log
      end
    rescue CFoundry::NotFound
      fail "Invalid path #{b(path)} for app #{b(app.name)}"
    rescue CFoundry::FileError => e
      fail e.description
    end

    def stream_path(lines, instance, path)
      if verbose?
        lines << [instance, path, c("streaming...", :good) + "\n"]
      end

      instance.stream_file(*path) do |contents|
        contents.each_line do |line|
          lines << [instance, path, line]
        end
      end

      lines << [instance, path, c("end of file", :bad) + "\n"]
    rescue Timeout::Error
      if verbose?
        lines << [
          instance,
          path,
          c("timed out; reconnecting...", :bad) + "\n"
        ]
      end

      retry
    end
  end
end

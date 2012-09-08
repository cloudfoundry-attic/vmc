module VMC
  class Detector
    def initialize(client, path)
      @client = client
      @path = path
    end

    def framework_info
      @framework_info ||= @client.info[:frameworks]
    end

    def all_runtimes
      @all_runtiems ||= @client.runtimes
    end

    def all_frameworks
      @all_frameworks ||= @client.frameworks

      @all_frameworks.each do |f|
        next if f.detection && f.runtimes

        if info = framework_info[f.name.to_sym]
          f.detection = info[:detection]

          runtime_names = info[:runtimes].collect { |r| r[:name] }
          f.runtimes = all_runtimes.select { |r|
            runtime_names.include?(r.name)
          }
        end
      end

      @all_frameworks
    end

    def frameworks
      matches = []
      all_frameworks.each do |framework|
        matched = false

        # e.g. standalone has no detection
        next if framework.detection.nil? || framework.detection.empty?

        framework.detection.first.each do |file, match|
          files =
            if File.file? @path
              if File.fnmatch(file, @path)
                [@path]
              elsif @path =~ /\.(zip|jar|war)/
                lines = CFoundry::Zip.entry_lines(@path)
                top = find_top(lines)

                lines.collect(&:name).select do |path|
                  File.fnmatch(file, path) ||
                    top && File.fnmatch(top + file, path)
                end
              else
                []
              end
            else
              Dir.glob("#@path/#{file}")
            end

          unless files.empty?
            if match == true
              matched = true
            elsif match == false
              matched = false
              break
            else
              begin
                files.each do |f|
                  contents = File.open(f, &:read)
                  if contents =~ Regexp.new(match)
                    matched = true
                  end
                end
              rescue RegexpError
                # some regexps may fail on 1.8 as the server runs 1.9
              end
            end
          end
        end

        matches << framework if matched
      end

      if matches.size == 1
        default = matches.first
      end

      [matches, default]
    end

    private

    def find_top(entries)
      found = false

      entries.each do |e|
        is_toplevel =
          e.ftype == :directory && e.name.index("/") + 1 == e.name.size

        if is_toplevel && e.name !~ /^(\.|__MACOSX)/
          if found
            return false
          else
            found = e.name
          end
        end
      end

      found
    end
  end
end

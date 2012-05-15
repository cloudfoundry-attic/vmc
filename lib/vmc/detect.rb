module VMC
  class Detector
    def initialize(client, path)
      @client = client
      @path = path
    end

    def all_frameworks
      info = @client.info
      info["frameworks"] || {}
    end

    def frameworks
      info = @client.info

      matches = {}
      all_frameworks.each do |name, meta|
        matched = false

        # e.g. standalone has no detection
        next if meta["detection"].nil?

        meta["detection"].first.each do |file, match|
          files =
            if File.file? @path
              if File.fnmatch(file, @path)
                [@path]
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
              files.each do |f|
                contents = File.open(f, &:read)
                if contents =~ Regexp.new(match)
                  matched = true
                end
              end
            end
          end
        end

        if matched
          matches[name] = meta
        end
      end

      if matches.size == 1
        default = matches.keys.first
      end

      [matches, default]
    end
  end
end

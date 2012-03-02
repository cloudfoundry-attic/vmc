require 'find'

module VMC::Micro
  def config_file(file)
    File.join(File.dirname(__FILE__), '..', '..', 'config', 'micro', file)
  end

  def escape_path(path)
    path = File.expand_path(path)
    if RUBY_PLATFORM =~ /mingw|mswin32|cygwin/
      if path.include?(' ')
        return '"' + path + '"'
      else
        return path
      end
    else
      return path.gsub(' ', '\ ')
    end
  end

  def locate_file(file, directory, search_paths)
    search_paths.each do |path|
      expanded_path = File.expand_path(path)
      if File.exists?(expanded_path)
        Find.find(expanded_path) do |current|
          if File.directory?(current) && current.include?(directory)
            full_path = File.join(current, file)
            return self.escape_path(full_path) if File.exists?(full_path)
          end
        end
      end
    end

    false
  end

  def run_command(command, args=nil)
    # TODO switch to using posix-spawn instead
    result = %x{#{command} #{args} 2>&1}
    unless $?.exitstatus == 0
      if block_given?
        yield
      else
        raise "failed to execute #{command} #{args}:\n#{result}"
      end
    else
      result.split(/\n/)
    end
  end

  module_function :config_file
  module_function :escape_path
  module_function :locate_file
  module_function :run_command

end

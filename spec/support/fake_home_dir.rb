require "fakefs/safe"

module FakeHomeDir
  def self.included(klass)
    super
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def stub_home_dir_with(&block)
      around do |example|
        bootstrap_dir = instance_exec(&block)

        if bootstrap_dir
          fixture = File.expand_path(bootstrap_dir)
          files = build_file_buffer(fixture)
        end

        FakeFS do
          home = File.expand_path("~")
          write_file_buffer(files, home) if files
          example.call
        end

        FakeFS::FileSystem.clear
      end
    end
  end

  private

  def build_file_buffer(path)
    files = {}

    Dir.glob("#{path}/**/*", File::FNM_DOTMATCH).each do |file|
      next if file =~ /\.$/
      next if File.directory?(file)

      files[file.sub(path + "/", "")] = File.read(file)
    end

    files
  end

  def write_file_buffer(files, path)
    files.each do |file, body|
      full = "#{path}/#{file}"

      FileUtils.mkdir_p(File.dirname(full))
      File.open(full, "w") do |io|
        io.write body
      end
    end
  end
end

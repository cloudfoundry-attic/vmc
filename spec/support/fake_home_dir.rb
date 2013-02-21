module FakeHomeDir
  def self.included(klass)
    super
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def use_fake_home_dir(&block)
      around do |example|
        dir = instance_exec(&block)
        with_fake_home_dir(dir) do
          example.call
        end
      end
    end

    def stub_home_dir_with(folder_name)
      around do |example|
        tmp_root = Dir.tmpdir
        FileUtils.cp_r(File.expand_path("#{SPEC_ROOT}/fixtures/fake_home_dirs/#{folder_name}"), tmp_root)
        fake_home_dir = "#{tmp_root}/#{folder_name}"
        begin
          with_fake_home_dir(fake_home_dir) do
            example.call
          end
        ensure
          FileUtils.rm_rf fake_home_dir
        end
      end
    end
  end

  def with_fake_home_dir(dir, &block)
    original_home_dir = ENV['HOME']
    ENV['HOME'] = dir
    begin
      block.call
    ensure
      ENV['HOME'] = original_home_dir
    end
  end
end

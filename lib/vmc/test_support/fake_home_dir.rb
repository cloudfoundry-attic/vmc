module VMC::TestSupport::FakeHomeDir
  def self.included(klass)
    def klass.use_fake_home_dir(&block)
      around do |example|
        dir = instance_exec(&block)
        original_home_dir = ENV['HOME']
        ENV['HOME'] = dir
        begin
          example.call
        ensure
          ENV['HOME'] = original_home_dir
        end
      end
    end
  end
end
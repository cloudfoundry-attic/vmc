def command(klass, &specs)
  describe klass do
    before do
      any_instance_of klass do |cli|
        stub(cli).precondition
        stub(cli).client { client }
      end
    end

    before(:all) do
      klass.class_eval do
        def wrap_errors
          yield
        rescue VMC::UserError => e
          err e.message
        end
      end
    end

    after(:all) do
      klass.class_eval do
        remove_method :wrap_errors
      end
    end

    class_eval(&specs)
  end
end

module CommandHelper
  def vmc(argv, script = false)
    Mothership.new.exit_status 0
    stub(VMC::CLI).exit { |code| code }
    capture_output { VMC::CLI.start(argv + ["--debug", "--no-script"]) }
  end

  def bool_flag(flag)
    "#{'no-' unless send(flag)}#{flag.to_s.gsub('_', '-')}"
  end

  attr_reader :stdout, :stderr, :stdin, :status

  def capture_output
    $real_stdout = $stdout
    $real_stderr = $stderr
    $real_stdin = $stdin
    $stdout = @stdout = StringIO.new
    $stderr = @stderr = StringIO.new
    $stdin = @stdin = StringIO.new
    @status = yield
    @stdout.rewind
    @stderr.rewind
    @status
  ensure
    $stdout = $real_stdout
    $stderr = $real_stderr
    $stdin = $real_stdin
  end

  def output
    @output ||= TrackingExpector.new(stdout)
  end

  def error_output
    @error_output ||= TrackingExpector.new(stderr)
  end

  def mock_invoke(*args)
    any_instance_of described_class do |cli|
      mock(cli).invoke *args
    end
  end

  def dont_allow_invoke(*args)
    any_instance_of described_class do |cli|
      dont_allow(cli).invoke *args
    end
  end
end

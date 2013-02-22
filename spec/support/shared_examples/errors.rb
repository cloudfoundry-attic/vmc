shared_examples_for "an error that's obvious to the user" do |options|
  message = options[:with_message]

  it "prints the message" do
    subject
    expect(stderr.string).to include message
  end

  it "sets the exit code to 1" do
    mock(context).exit_status(1)
    subject
  end

  it "does not mention ~/.vmc/crash" do
    subject
    expect(stderr.string).to_not include VMC::CRASH_FILE
  end
end

shared_examples_for "an error that gets passed through" do |options|
  before do
    described_class.class_eval do
      alias_method :wrap_errors_original, :wrap_errors
      def wrap_errors
        yield
      end
    end
  end

  after do
    described_class.class_eval do
      remove_method :wrap_errors
      alias_method :wrap_errors, :wrap_errors_original
    end
  end

  it "reraises the error" do
    expect { subject }.to raise_error(options[:with_exception], options[:with_message])
  end
end

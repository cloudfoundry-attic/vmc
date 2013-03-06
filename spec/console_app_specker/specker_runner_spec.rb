require 'spec_helper'

describe SpeckerRunner, :ruby19 => true do
  def asset(file)
    File.expand_path("../../assets/specker_runner/#{file}", __FILE__)
  end

  let(:timeout) { 1 }

  describe "running a command" do
    let(:file) do
      file = Tempfile.new('test-specker-runner')
      sleep 1  # wait one second to make sure touching the file does something measurable
      file
    end

    after { file.unlink }

    it "runs a command" do
      run("touch -a #{file.path}") do |runner|
        runner.wait_for_exit
        file.stat.atime.should > file.stat.mtime
      end
    end
  end

  describe "#expect" do
    context "when the expected output shows up" do
      it "returns a truthy value" do
        run("echo -n foo") do |runner|
          expect(runner.expect('foo')).to be_true
        end
      end
    end

    context "when the expected output never shows up" do
      it "returns nil" do
        run("echo the spanish inquisition") do |runner|
          expect(runner.expect("something else", 0.5)).to be_nil
        end
      end
    end

    context "when the output eventually shows up" do
      it "returns a truthy value" do
        run("ruby #{asset("specker_runner_pause.rb")}") do |runner|
          expect(runner.expect("finished")).to be_true
        end
      end
    end

    context "backspace" do
      it "respects the backspace character" do
        run("ruby -e 'puts \"foo a\\bbar\"'") do |runner|
          expect(runner.expect("foo bar")).to be_true
        end
      end

      it "does not go beyond the beginning of the line" do
        run("ruby -e 'print \"foo abc\nx\\b\\bd\"'") do |runner|
          expect(runner.expect("foo abc\nd")).to be_true
        end
      end

      it "does not go beyond the beginning of the string" do
        run("ruby -e 'print \"f\\b\\bbar\"'") do |runner|
          expect(runner.expect("bar")).to be_true
        end
      end

      it "leaves backspaced characters in the buffer until they're overwritten" do
        run("ruby -e 'print \"foo abc\\b\\bd\"'") do |runner|
          expect(runner.expect("foo adc")).to be_true
        end
      end
    end

    context "ansi escape sequences" do
      it "filters ansi color sequences" do
        run("ruby -e 'puts \"\\e[36mblue\\e[0m thing\"'") do |runner|
          expect(runner.expect("blue thing")).to be_true
        end
      end
    end

    context "expecting multiple branches" do
      context "and one of them matches" do
        it "can be passed a hash of values with callbacks, and returns the matched key" do
          run("echo 1 3") do |runner|
            branches = {
              "1" => proc { 1 },
              "2" => proc { 2 },
              "3" => proc { 3 }
            }

            expect(runner.expect(branches)).to eq "1"
            expect(runner.expect(branches)).to eq "3"
          end
        end

        it "calls the matched callback" do
          callback = mock!
          run("echo 1 3") do |runner|
            branches = {
              "1" => proc { callback }
            }
            runner.expect(branches)
          end
        end
      end

      context "and none of them match" do
        it "returns nil when none of the branches match" do
          run("echo not_a_number") do |runner|
            expect(runner.expect({"1" => proc { 1 }}, timeout)).to be_nil
          end
        end
      end
    end
  end

  describe "#output" do
    it "makes the entire command output (so far) available" do
      run("echo 0 1 2 3") do |runner|
        runner.expect("1")
        runner.expect("3")
        expect(runner.output).to eq "0 1 2 3"
      end

    end
  end

  describe "#send_keys" do
    it "sends input and expects more output afterward" do
      run("ruby #{asset("specker_runner_input.rb")}") do |runner|
        expect(runner.expect("started")).to be_true
        runner.send_keys("foo")
        expect(runner.expect("foo")).to be_true
      end
    end
  end

  context "#exit_code" do
    it "returns the exit code" do
      run("ruby -e 'exit 42'") do |runner|
        runner.wait_for_exit
        expect(runner.exit_code).to eq(42)
      end
    end

    context "when the command is still running" do
      it "waits for the command to exit" do
        run("sleep 0.5") do |runner|
          expect(runner.exit_code).to eq(0)
        end
      end
    end
  end

  context "#exited?" do
    it "returns false if the command is still running" do
      run("sleep 10") do |runner|
        expect(runner.exited?).to eq false
      end
    end
  end
end

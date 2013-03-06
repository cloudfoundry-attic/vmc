require 'spec_helper'
include ConsoleAppSpeckerMatchers

describe ConsoleAppSpeckerMatchers, :ruby19 => true do
  describe "#say" do
    it "returns an ExpectOutputMatcher" do
      say("").should be_a(ExpectOutputMatcher)
    end

    context "with an explicit timeout" do
      it "returns an ExpectOutputMatcher" do
        matcher = say("", 30)
        matcher.should be_a(ExpectOutputMatcher)
        matcher.timeout.should == 30
      end
    end
  end

  describe "#have_exited_with" do
    it "returns an ExitCodeMatcher" do
      have_exited_with(1).should be_a(ExitCodeMatcher)
    end

    it "has synonyms" do
      exit_with(1).should be_a(ExitCodeMatcher)
    end
  end
end

describe ExpectOutputMatcher, :ruby19 => true do
  let(:expected_output) { "expected_output" }
  let(:timeout) { 1 }

  subject { ExpectOutputMatcher.new(expected_output, timeout) }

  describe "#matches?" do
    context "with something that isn't a runner" do
      it "raises an exception" do
        expect {
          subject.matches?("c'est ne pas une specker runner")
        }.to raise_exception(InvalidInputError)
      end
    end

    context "with a valid runner" do
      context "when the expected output is in the process output" do
        it "finds the expected output" do
          run("echo -n expected_output") do |runner|
            subject.matches?(runner).should be_true
          end
        end
      end

      context "when the expected output is not in the process output" do
        let(:runner) { SpeckerRunner.new('echo -n not_what_we_were_expecting') }

        it "does not find the expected output" do
          run("echo -n not_what_we_were_expecting") do |runner|
            subject.matches?(runner).should be_false
          end
        end
      end
    end
  end

  context "failure messages" do
    it "has a correct failure message" do
      run("echo -n actual_output") do |runner|
        subject.matches?(runner)
        subject.failure_message.should == "expected 'expected_output' to be printed, but it wasn't. full output:\nactual_output"
      end
    end

    it "has a correct negative failure message" do
      run("echo -n actual_output") do |runner|
        subject.matches?(runner)
        subject.negative_failure_message.should == "expected 'expected_output' to not be printed, but it was. full output:\nactual_output"
      end
    end

    context "when expecting branching output" do
      let(:expected_output) { {
        "expected_output" => proc {},
        "other_expected_output" => proc {}
      } }

      it "has a correct failure message" do
        run("echo -n actual_output") do |runner|
          subject.matches?(runner)
          subject.failure_message.should == "expected one of 'expected_output', 'other_expected_output' to be printed, but it wasn't. full output:\nactual_output"
        end
      end

      it "has a correct negative failure message" do
        run("echo -n expected_output") do |runner|
          subject.matches?(runner)
          subject.negative_failure_message.should == "expected 'expected_output' to not be printed, but it was. full output:\nexpected_output"
        end
      end
    end
  end
end

describe ExitCodeMatcher, :ruby19 => true do
  let(:expected_code) { 0 }

  subject { ExitCodeMatcher.new(expected_code) }

  describe "#matches?" do
    context "with something that isn't a runner" do
      it "raises an exception" do
        expect {
          subject.matches?("c'est ne pas une specker runner")
        }.to raise_exception(InvalidInputError)
      end
    end

    context "with a valid runner" do
      context "and the command exited with the expected exit code" do
        it "returns true" do
          run("true") do |runner|
            subject.matches?(runner).should be_true
          end
        end
      end

      context "and the command exits with a different exit code" do
        it "returns false" do
          run("false") do |runner|
            subject.matches?(runner).should be_false
          end
        end
      end

      context "and the command runs for a while" do
        it "waits for it to exit" do
          run("sleep 0.5") do |runner|
            subject.matches?(runner).should be_true
          end
        end
      end
    end
  end

  context "failure messages" do
    context "with a command that's exited" do
      it "has a correct failure message" do
        run("false") do |runner|
          subject.matches?(runner)
          runner.wait_for_exit
          subject.failure_message.should == "expected process to exit with status 0, but it exited with status 1"
        end
      end

      it "has a correct negative failure message" do
        run("false") do |runner|
          subject.matches?(runner)
          runner.wait_for_exit
          subject.negative_failure_message.should == "expected process to not exit with status 0, but it did"
        end
      end
    end

    context "with a command that's still running" do
      it "waits for it to exit" do
        run("ruby -e 'sleep 1; exit 1'") do |runner|
          subject.matches?(runner)
          subject.failure_message.should == "expected process to exit with status 0, but it exited with status 1"
        end
      end
    end
  end
end

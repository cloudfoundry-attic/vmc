require "rspec"

require "cfoundry"
require "vmc"

require "vmc/spec_helpers/eventlog"
require "vmc/spec_helpers/patches"


module VMCHelpers
  TARGET = ENV["VMC_TEST_TARGET"] || "http://localhost:8181"
  USER = ENV["VMC_TEST_USER"] || "sre@vmware.com"
  PASSWORD = ENV["VMC_TEST_PASSWORD"] || "test"

  def random_str
    format("%x", rand(1000000))
  end

  def client
    VMC::CLI.client
  end

  # invoke a block while logged out
  def without_auth
    proxy = client.proxy
    client.logout
    client.proxy = nil
    yield
  ensure
    client.login(USER, PASSWORD)
    client.proxy = proxy
  end

  # same as Ruby 1.9's Array#sample
  def sample(ary)
    ary[rand(ary.size)]
  end

  # cache frameworks for app generation
  def frameworks
    @@frameworks ||= client.frameworks(0)
  end

  # cache runtimes for app generation
  def runtimes
    @@runtimes ||= client.runtimes(0)
  end

  def with_random_app(space = client.current_space)
    with_random_apps(space, 1) do |apps|
      yield apps.first
    end
  end

  # create 2-5 random apps, call the block, and then delete them
  def with_random_apps(space = client.current_space, num = rand(3) + 2)
    apps = []

    num.times do |n|
      app = client.app
      app.name = "app-#{n + 1}-#{random_str}"
      app.space = space
      app.instances = rand(2)

      app.framework = sample(frameworks)
      app.runtime = sample(runtimes)
      app.memory = sample([64, 128, 256, 512])
      app.create!

      apps << app
    end

    yield apps
  ensure
    apps.each(&:delete!)
  end

  def with_new_space(org = client.current_organization)
    space = client.space
    space.name = "space-#{random_str}"
    space.organization = org
    space.create!

    yield space
  ensure
    space.delete!
  end

  def running(command, inputs = {}, given = {})
    VMC::CLI.new.exit_status 0

    before_in = $stdin
    before_out = $stdout
    before_err = $stderr
    before_event = $vmc_event

    tty = FakeTTY.new

    $vmc_event = EventLog.new(tty)

    $stdin = tty
    $stdout = StringIO.new
    $stderr = StringIO.new

    main = Thread.current

    thd_group = ThreadGroup.new
    thd = Thread.new do
      thd_group.add(thd)
      begin
        VMC::CLI.new.invoke(command, inputs, given, :quiet => true)
      rescue SystemExit => e
        unless e.status == 0
          raise <<EOF
execution failed with status #{e.status}!

stdout:
#{$stdout.string}

stderr:
#{$stderr.string}
EOF
        end
      rescue => e
        $vmc_event.raised(e)
      end
    end

    begin
      $vmc_event.process = thd

      yield $vmc_event

      $vmc_event.should complete
    ensure
      thd_group.list.each(&:kill)
    end
  ensure
    $stdin = before_in
    $stdout = before_out
    $stderr = before_err
    $vmc_event = before_event
  end
end

module VMCMatchers
  class Contain
    def initialize(content)
      @content = content
    end

    def matches?(actual)
      @actual = actual
      true
    end

    def failure_message
      "expected '#@content' to be in the output"
    end

    def negative_failure_message
      "expected '#@content' to NOT be in the output"
    end
  end

  def contain(content)
    Contain.new(content)
  end

  class Ask
    def initialize(message)
      @message = message
    end

    def matches?(log)
      ev = log.wait_for_event(EventLog::Asked)

      @actual = ev.message
      @actual == @message
    end

    def failure_message
      "expected to be asked '#@message', got '#@actual'"
    end

    def negative_failure_message
      "expected to NOT be asked for #@message"
    end
  end

  def ask(message)
    Ask.new(message)
  end

  class HaveInput
    def initialize(name, value = nil)
      @name = name
      @expected = value
    end

    def matches?(log)
      input = log.wait_for_event(EventLog::GotInput)
      until input.name == @name
        input = log.wait_for_event(EventLog::GotInput)
      end

      @actual = input.value
      @actual == @expected
    end

    def failure_message
      "expected to have input '#@name' as '#@expected', but got '#@actual'"
    end

    def negative_failure_message
      "expected not to have input '#@name', but had it as '#@actual'"
    end
  end

  def have_input(name, value = nil)
    HaveInput.new(name, value)
  end

  class Output
    def initialize(line)
      @expected = line
    end

    def matches?(log)
      @actual = log.wait_for_event(EventLog::Printed).line
      @actual == @expected
    end

    def failure_message
      "expected '#@expected' to be in the output, but got '#@actual'"
    end

    def negative_failure_message
      "expected '#@expected' NOT to be in the output, but it was"
    end
  end

  def output(line)
    Output.new(line)
  end

  class Complete
    def matches?(log)
      @log = log

      log.process.join(1)

      log.process.status == false
    end

    def failure_message
      pending = @log.pending_events

      if @exception
        "process existed with an exception: #@exception"
      elsif !pending.empty?
        "expected process to complete, but it's pending events #{pending}"
      else
        "process is blocked; status: #{@log.process.status}"
      end
    end

    def negative_failure_message
      "expected process to still be running, but it's completed"
    end
  end

  def complete
    Complete.new
  end


  class FailWith
    def initialize(exception, predicate = nil)
      @expected = exception
      @predicate = predicate
    end

    def matches?(log)
      @actual = log.wait_for_event(EventLog::Raised).exception

      return false unless @actual.is_a?(@expected)

      @predicate.call(@actual) if @predicate

      true
    end

    def failure_message
      "expected #@expected to be raised, but got #{@actual.class}: '#@actual'"
    end

    def negative_failure_message
      "expected #@expected to NOT be raised, but it was"
    end
  end

  def fail_with(exception, &blk)
    FailWith.new(exception, blk)
  end


  class ProgressExpectation
    def matches?(log)
      @actual = log.wait_for_event(EventLog::Progress)
      @actual == @expected
    end

    def failure_message
      "expected to #{@expected.report}, but #{@actual.report_past} instead"
    end

    def negative_failure_message
      "expected not to #{@expected.report}"
    end
  end

  class Successfully < ProgressExpectation
    def initialize(message)
      @expected = EventLog::Did.new(message)
    end
  end

  class Skip < ProgressExpectation
    def initialize(message)
      @expected = EventLog::Skipped.new(message)
    end
  end

  class FailTo < ProgressExpectation
    def initialize(message)
      @expected = EventLog::FailedTo.new(message)
    end
  end

  class GiveUp < ProgressExpectation
    def initialize(message)
      @expected = EventLog::GaveUp.new(message)
    end
  end

  def successfully(message)
    Successfully.new(message)
  end

  def skip(message)
    Skip.new(message)
  end

  def fail_to(message)
    FailTo.new(message)
  end

  def give_up(message)
    GiveUp.new(message)
  end


  def asks(what)
    $vmc_event.should ask(what)
  end

  def given(what)
    $vmc_event.provide("#{what}\n")
  end

  def has_input(name, value = nil)
    $vmc_event.should have_input(name, value)
  end

  def raises(exception, &blk)
    $vmc_event.should fail_with(exception, &blk)
  end

  def finish
    $vmc_event.should complete
  end

  def outputs(what)
    $vmc_event.should output(what)
  end

  def does(what)
    $vmc_event.should successfully(what)
  end

  def skips(what)
    $vmc_event.should skip(what)
  end

  def fails_to(what)
    $vmc_event.should fail_to(what)
  end

  def gives_up(what)
    $vmc_event.should give_up(what)
  end

  def kill
    $vmc_event.kill_process
  end
end

RSpec.configure do |c|
  c.include VMCHelpers
  c.include VMCMatchers

  c.before(:all) do
    VMC::CLI.client = CFoundry::Client.new(VMCHelpers::TARGET)

    client.login(
      :username => VMCHelpers::USER,
      :password => VMCHelpers::PASSWORD)

    unless client.is_a? CFoundry::V1::Client
      client.current_organization = client.organizations.first
      client.current_space = client.current_organization.spaces.first
    end
  end
end


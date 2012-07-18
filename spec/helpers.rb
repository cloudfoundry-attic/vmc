require "cfoundry"
require "vmc"

TARGET = ENV["VMC_TEST_TARGET"] || "http://localhost:8181"
USER = ENV["VMC_TEST_USER"] || "sre@vmware.com"
PASSWORD = ENV["VMC_TEST_PASSWORD"] || "test"

module VMCHelpers
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

  def with_random_app
    with_random_apps(1)
  end

  # create 2-5 random apps, call the block, and then delete them
  def with_random_apps(num = rand(3) + 2)
    apps = []

    num.times do |n|
      app = client.app
      app.name = "app-#{n + 1}-#{random_str}"
      app.space = client.current_space
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

  # invoke a command with a given arglist
  def shell(*argv)
    before_out = $stdout
    before_err = $stderr

    $stdout = StringIO.new
    $stderr = StringIO.new

    begin
      VMC::CLI.start(argv)
    rescue SystemExit => e
      unless e.status == 0
        raise "execution failed! output:\n#{$stderr.string}"
      end
    end

    $stdout.string
  ensure
    $stdout = before_out
    $stderr = before_err
  end
end

RSpec.configure do |c|
  c.include VMCHelpers

  c.before(:all) do
    VMC::CLI.client = CFoundry::Client.new(TARGET)

    client.login(:username => USER, :password => PASSWORD)
    client.current_organization = client.organizations.first
    client.current_space = client.current_organization.spaces.first
  end
end

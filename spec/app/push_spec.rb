require "./helpers"

describe "App#push" do
  it "pushes interactively" do
    name = "app-#{random_str}"
    instances = 1 # rand(3) + 1
    framework = client.framework_by_name("sinatra")
    runtime = client.runtime_by_name("ruby19")
    url = "#{name}.fakecloud.com"
    memory = 256 # sample([64, 128, 256, 512])

    client.app_by_name(name).should_not be

    hello_sinatra = File.expand_path("../../assets/hello-sinatra", __FILE__)

    begin
      running(:push, :path => hello_sinatra) do
        asks("Name")
        given(name)
        has_input(:name, name)

        asks("Instances")
        given(instances)
        has_input(:instance, instances)

        asks("Framework")
        given(framework.name)
        has_input(:framework, framework)

        asks("Runtime")
        given(runtime.name)
        has_input(:runtime, runtime)

        asks("URL")
        given(url)
        has_input(:url, url)

        asks("Memory Limit")
        given("#{memory}M")
        has_input(:memory, "#{memory}M")

        does("Creating #{name}")

        asks("Create services for application?")
        given("n")
        has_input(:create_instances, false)

        asks("Bind other services to application?")
        given("n")
        has_input(:bind_instances, false)

        does("Uploading #{name}")
        does("Starting #{name}")
      end

      app = client.app_by_name(name)

      app.should be
      app.name.should == name
      app.instances.should == instances
      app.framework.should == framework
      app.runtime.should == runtime
      #app.url.should == url # TODO v2
      app.memory.should == memory
    ensure
      if created = client.app_by_name(name)
        created.delete!
      end
    end
  end
end

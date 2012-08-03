require "./helpers"

describe "App#push" do
  it "pushes interactively" do
    name = "app-#{random_str}"
    instances = rand(3) + 1
    framework = sample(client.frameworks)
    runtime = sample(client.runtimes)
    url = "#{name}.fakecloud.com"
    memory = sample([64, 128, 256, 512])

    client.app_by_name(name).should_not be

    begin
      running(:push) do
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

        asks("Create services for application?")
        given("n")
        has_input(:create_instances, false)

        asks("Bind other services to application?")
        given("n")
        has_input(:bind_instances, false)
      end
    rescue VMC::UserError => e
      unless e.to_s == "V2 API currently does not support uploading or starting apps."
        raise
      end
    end

    app = client.app_by_name(name)

    begin
      app.should be
      app.name.should == name
      app.instances.should == instances
      app.framework.should == framework
      app.runtime.should == runtime
      #app.url.should == url # TODO v2
      app.memory.should == memory
    ensure
      app.delete!
    end
  end
end

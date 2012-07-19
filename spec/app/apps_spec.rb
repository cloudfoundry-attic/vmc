require "./helpers"

describe "App#apps" do
  it "lists app names" do
    with_random_apps do |apps|
      shell("apps").split("\n").should =~
        apps.collect(&:name)
    end
  end

  it "filters by name with --name" do
    with_random_apps do |apps|
      app = apps[rand(apps.size)]

      result = shell("apps", "--name", app.name).split("\n")
      result.should =~ [app.name]
    end
  end

  it "filters by runtime with --runtime" do
    with_random_apps do |apps|
      app = apps[rand(apps.size)]

      result = shell("apps", "--runtime", app.runtime.name).split("\n")
      actual =
        apps.select { |a|
          /#{app.runtime.name}/ =~ a.runtime.name
        }.collect(&:name)

      result.should =~ actual
    end
  end

  it "filters by framework with --framework" do
    with_random_apps do |apps|
      app = apps[rand(apps.size)]

      result = shell("apps", "--framework", app.framework.name).split("\n")
      actual =
        apps.select { |a|
          /#{app.framework.name}/ =~ a.framework.name
        }.collect(&:name)

      result.should =~ actual
    end
  end

  # TODO: use space other than current
  it "can be told which space with --space" do
    with_random_apps do |apps|
      app = apps[rand(apps.size)]

      result = shell("apps", "--space", client.current_space.name).split("\n")
      actual = client.current_space.apps.collect(&:name)

      result.should =~ actual
    end
  end

  # TODO: v2
  #it "filters by url with --url" do
    #with_random_apps do |apps|
      #app = apps[rand(apps.size)]
      #url = app.urls[rand(app.urls.size)]

      #result = shell("apps", "--url", url).split("\n")
      #actual =
        #apps.select { |a|
          #a.urls.include? url
        #}.collect(&:name)

      #result.should =~ actual
    #end
  #end
end

require File.expand_path("../../helpers", __FILE__)

describe "App#apps" do
  it "lists app names" do
    with_random_apps do |apps|
      running(:apps) do
        does("Getting applications in #{client.current_space.name}")

        apps.sort_by(&:name).each do |a|
          outputs(a.name)
        end
      end
    end
  end

  it "filters by name with --name" do
    with_random_apps do |apps|
      name = sample(apps).name

      running(:apps, :name => name) do
        does("Getting applications in #{client.current_space.name}")

        apps.sort_by(&:name).each do |a|
          if a.name == name
            outputs(a.name)
          end
        end
      end
    end
  end

  it "filters by runtime with --runtime" do
    with_random_apps do |apps|
      runtime = sample(apps).runtime

      running(:apps, :runtime => runtime.name) do
        does("Getting applications in #{client.current_space.name}")

        apps.sort_by(&:name).each do |a|
          if a.runtime =~ /#{runtime}/
            outputs(a.name)
          end
        end
      end
    end
  end

  it "filters by framework with --framework" do
    with_random_apps do |apps|
      framework = sample(apps).framework

      running(:apps, :framework => framework.name) do
        does("Getting applications in #{client.current_space.name}")

        apps.sort_by(&:name).each do |a|
          if a.framework == framework
            outputs(a.name)
          end
        end
      end
    end
  end

  it "can be told which space with --space" do
    with_new_space do |space|
      with_random_apps do |other_apps|
        with_random_apps(space) do |apps|
          running(:apps, :space => space) do
            does("Getting applications in #{space.name}")

            apps.sort_by(&:name).each do |a|
              outputs(a.name)
            end
          end
        end
      end
    end
  end
end

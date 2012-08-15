require File.expand_path("../../helpers", __FILE__)

describe "App#app" do
  it "shows the app name if it exists" do
    with_random_app do |app|
      running(:app, {}, :app => app.name) do
        outputs(app.name)
      end
    end
  end

  it "fails if an unknown app is provided" do
    running(:app, {}, :app => "unknown-app") do
      raises(VMC::UserError) do |e|
        e.message.should == "Unknown app 'unknown-app'"
      end
    end
  end
end

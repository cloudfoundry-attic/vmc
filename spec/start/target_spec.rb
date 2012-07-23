require "./helpers"

describe "Start#target" do
  it "shows target url with no arguments" do
    shell("target").rstrip.should == client.target
  end

  describe "switching target url" do
    before(:all) do
      @old_target = File.read(File.expand_path(VMC::TARGET_FILE))
    end

    after(:all) do
      File.open(File.expand_path(VMC::TARGET_FILE), "w") do |io|
        io.print @old_target
      end
    end

    before(:each) do
      @old_client = client
    end

    after(:each) do
      VMC::CLI.client = @old_client
    end

    it "switches target url if given one argument" do
      shell("target", "http://api.cloudfoundry.com")
      client.target.should == "http://api.cloudfoundry.com"
    end

    it "defaults to https if supported by remote" do
      shell("target", "api.cloudfoundry.com")
      client.target.should == "https://api.cloudfoundry.com"
    end

    # TODO: this assumes locally running cc without https support
    it "defaults to http if not supported by remote" do
      base_target = client.target.sub(/^https?:\/\//, "")
      shell("target", base_target)
      client.target.should == "http://#{base_target}"
    end
  end
end

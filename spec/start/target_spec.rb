require "./helpers"

describe "Start#target" do
  it "shows target url with no arguments" do
    running(:target) do
      outputs(client.target)
    end
  end

  describe "switching target url" do
    before(:all) do
      tgt = File.expand_path(VMC::TARGET_FILE)
      @old_target = File.read(tgt) if File.exists? tgt
    end

    after(:all) do
      tgt = File.expand_path(VMC::TARGET_FILE)

      if @old_target
        File.open(tgt, "w") do |io|
          io.print @old_target
        end
      else
        File.delete(tgt)
      end
    end

    before(:each) do
      @old_client = client
    end

    after(:each) do
      VMC::CLI.client = @old_client
    end

    it "switches target url if given one argument" do
      running(:target, :url => "http://api.cloudfoundry.com") do
        finish
        client.target.should == "http://api.cloudfoundry.com"
      end
    end

    it "defaults to https if supported by remote" do
      running(:target, :url => "api.cloudfoundry.com") do
        finish
        client.target.should == "https://api.cloudfoundry.com"
      end
    end

    # TODO: this assumes locally running cc without https support
    it "defaults to http if not supported by remote" do
      base_target = client.target.sub(/^https?:\/\//, "")

      running(:target, :url => base_target) do
        finish
        client.target.should == "http://#{base_target}"
      end
    end
  end
end

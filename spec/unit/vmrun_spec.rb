require 'spec_helper'

describe VMC::Micro::VMrun do

  before(:all) do
    platform = VMC::Cli::Command::Micro.platform
    @config = {'platform' => platform, 'password' => 'pass', 'vmrun' => 'vmrun', 'vmx' => 'vmx'}
  end

  it "should list all VMs running" do
    v = VMC::Micro::VMrun.new(@config)
    v.should_receive(:run).and_return(["Total ...", "/foo.vmx", "/bar.vmx"])
    v.list.should == ["/foo.vmx", "/bar.vmx"]
  end

  describe "connection type" do
    it "should list the connection type" do
      vmrun = VMC::Micro::VMrun.new(@config)
      vmrun.should_receive(:run).and_return(["bridged"])
      vmrun.connection_type == "bridged"
    end
  end
end

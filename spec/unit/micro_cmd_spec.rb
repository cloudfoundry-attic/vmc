require 'spec_helper'

describe VMC::Cli::Command::Micro do
  VMRUN = "/path/to/vmrun"
  VMX = "/path/to/micro.vmx"
  PASSWORD = "password"

  describe "#build_config" do
    it "should ask for info when the config is empty" do
      VMC::Cli::Config.should_receive(:micro).and_return({})
      cmd = VMC::Cli::Command::Micro.new({})

      cmd.should_receive(:locate_vmx).and_return(VMX)
      VMC::Micro::VMrun.should_receive(:locate).and_return(VMRUN)
      cmd.should_receive(:ask).and_return(PASSWORD)

      config = cmd.build_config
      config['vmx'].should == VMX
      config['vmrun'].should == VMRUN
      config['password'].should == PASSWORD
    end

    it "should override stored config with command line arguments" do
      VMC::Cli::Config.should_receive(:micro).and_return({})
      options = {:password => PASSWORD, :vmx => VMX, :vmrun => VMRUN}
      cmd = VMC::Cli::Command::Micro.new(options)

      config = cmd.build_config
      config['vmx'].should == VMX
      config['vmrun'].should == VMRUN
      config['password'].should == PASSWORD
    end
  end
end

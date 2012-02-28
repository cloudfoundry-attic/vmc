require 'spec_helper'

describe VMC::Micro::Switcher::Base do
  it "should go online" do
    vmrun = double(VMC::Micro::VMrun)
    vmrun.should_receive(:running?).and_return(true)
    vmrun.should_receive(:ready?).and_return(true)
    vmrun.should_receive(:offline?).and_return(false)
    VMC::Micro::VMrun.should_receive(:new).and_return(vmrun)
    switcher = VMC::Micro::Switcher::Dummy.new({})
    switcher.online
  end
  it "should go offline" do
    vmrun = double(VMC::Micro::VMrun)
    vmrun.should_receive(:running?).and_return(true)
    vmrun.should_receive(:ready?).and_return(true)
    vmrun.should_receive(:offline?).and_return(true)
    VMC::Micro::VMrun.should_receive(:new).and_return(vmrun)
    switcher = VMC::Micro::Switcher::Dummy.new({})
    switcher.offline
  end
end

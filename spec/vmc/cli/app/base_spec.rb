require 'spec_helper'
require "vmc/cli/app/base"

describe VMC::App::Base do
  describe '#human_size' do
    let(:base) { VMC::App::Base.new }

    it { base.human_size(1_023).should == "1023.0B" }
    it { base.human_size(1_024).should == "1.0K" }
    it { base.human_size(1_024 * 1_024).should == "1.0M" }
    it { base.human_size(1_024 * 1_024 * 1.5).should == "1.5M" }
    it { base.human_size(1_024 * 1_024 * 1_024).should == "1.0G" }
    it { base.human_size(1_024 * 1_024 * 1_024 * 1.5).should == "1.5G" }
    it { base.human_size(1_024 * 1_024 * 1_024 * 1.234, 3).should == "1.234G" }
    it { base.human_size(31395840).should == "29.9M" } # tests against floating point errors
  end
end
require 'spec_helper'
require 'stringio'

describe VMC::App::Stats do
  let(:global) { { :color => false } }
  let(:inputs) { { :app => apps[0] } }
  let(:given) { {} }
  let(:client) { fake_client(:apps => apps) }
  let(:apps) { [fake(:app, :name => "basic_app")] }
  let(:time) { Time.local(2012, 11, 1, 2, 30) }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
    stub(client.base).instances(anything) do
      {
        "12" => {:state => "STOPPED", :since => time.to_i, :debug_ip => "foo", :debug_port => "bar", :console_ip => "baz", :console_port => "qux"},
        "1" => {:state => "STOPPED", :since => time.to_i, :debug_ip => "foo", :debug_port => "bar", :console_ip => "baz", :console_port => "qux"},
        "2" => {:state => "STARTED", :since => time.to_i, :debug_ip => "foo", :debug_port => "bar", :console_ip => "baz", :console_port => "qux"}
      }
    end
  end

  subject do
    capture_output do
      Mothership.new.invoke(:instances, inputs, given, global)
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:instances] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "List an app's instances" }
      it { expect(Mothership::Help.group(:apps, :info)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has no arguments' do
        should eq([{:type=>:splat, :value=>nil, :name=>:apps}])
      end
    end
  end

  it 'prints out the instances in the correct order' do
    subject
    expect(output).to say("instance #1")
    expect(output).to say("instance #2")
    expect(output).to say("instance #12")
  end

  it 'prints out one of the instances correctly' do
    subject
    expect(output).to say("instance #2: started")
    expect(output).to say("  started: #{time.strftime("%F %r")}")
    expect(output).to say("  debugger: port bar at foo")
    expect(output).to say("  console: port qux at baz")
  end
end

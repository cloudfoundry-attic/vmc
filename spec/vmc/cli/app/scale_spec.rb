require "spec_helper"
require "webmock/rspec"

describe VMC::App::Scale do
  let(:global) { { :color => false } }
  let(:given) { {} }
  let(:client) { fake_client }
  let!(:cli) { described_class.new }

  before do
    stub(cli).client { client }
    stub_output(cli)
  end

  subject { invoke_cli(cli, :scale, inputs, given, global) }

  context "when the --disk flag is given" do
    let(:before_value) { 512 }
    let(:app) { fake :app, :disk_quota => before_value }
    let(:inputs) { { :app => app, :disk => "1G" } }

    it "changes the application's disk quota" do
      mock(app).update!
      expect { subject }.to change(app, :disk_quota).from(before_value).to(1024)
    end
  end

  context "when the --memory flag is given" do
    let(:before_value) { 512 }
    let(:app) { fake :app, :memory => before_value }
    let(:inputs) { { :app => app, :memory => "1G" } }

    it "changes the application's memory" do
      mock(app).update!
      expect { subject }.to change(app, :memory).from(before_value).to(1024)
    end

    context "if --restart is true" do
      it "restarts the application" do
        stub(app).update!
        stub(app).started? { true }
        mock(cli).invoke :restart, :app => app
        subject
      end
    end
  end

  context "when the --instances flag is given" do
    let(:before_value) { 3 }
    let(:app) { fake :app, :total_instances => before_value }

    let(:inputs) { { :app => app, :instances => 5 } }

    it "changes the application's number of instances" do
      mock(app).update!
      expect { subject }.to change(app, :total_instances).from(before_value).to(5)
    end
  end

  context "when the --plan flag is given" do
    context "when the plan name begins with a 'p'" do
      let(:app) { fake :app, :production => false }
      let(:inputs) { { :app => app, :plan => "P100" } }

      it "changes the application's 'production' flag to true" do
        mock(app).update!
        expect { subject }.to change(app, :production).from(false).to(true)
      end
    end

    context "when the plan name does not begin with a 'p'" do
      let(:app) { fake :app, :production => true }
      let(:inputs) { { :app => app, :plan => "D100" } }

      it "changes the application's 'production' flag to false" do
        mock(app).update!
        expect { subject }.to change(app, :production).from(true).to(false)
      end
    end
  end
end

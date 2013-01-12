require 'spec_helper'

describe VMC::Domain::Unmap do
  let(:global) { { :color => false } }
  let(:given) { {} }
  let(:client) { fake_client :current_organization => organization, :current_space => space }
  let!(:cli) { described_class.new }

  before do
    stub(cli).client { client }
    stub_output(cli)
  end

  let(:organization) { fake(:organization) }
  let(:space) { fake(:space) }
  let(:domain) { fake(:domain, :name => domain_name) }
  let(:domain_name) { "some.domain.com" }

  subject { invoke_cli(cli, :unmap_domain, inputs, given, global) }

  context "when the --delete flag is given" do
    let(:inputs) { { :domain => domain, :delete => true } }

    it "asks for a confirmation" do
      mock_ask("Really delete #{domain_name}?", :default => false) { false }
      stub(domain).delete!
      subject
    end

    context "and the user answers 'no' to the confirmation" do
      it "does NOT delete the domain" do
        stub_ask("Really delete #{domain_name}?", anything) { false }
        dont_allow(domain).delete!
        subject
      end
    end

    context "and the user answers 'yes' to the confirmation" do
      it "deletes the domain" do
        stub_ask("Really delete #{domain_name}?", anything) { true }
        mock(domain).delete!
        subject
      end
    end
  end

  context "when a space is given" do
    let(:inputs) { { :domain => domain, :space => space } }

    it "unmaps the domain from the space" do
      mock(space).remove_domain(domain)
      subject
    end
  end

  context "when an organization is given" do
    let(:inputs) { { :domain => domain, :organization => organization } }

    it "unmaps the domain from the organization" do
      mock(organization).remove_domain(domain)
      subject
    end
  end

  context "when only the domain is given" do
    let(:inputs) { { :domain => domain } }

    it "unmaps the domain from the current space" do
      mock(client.current_space).remove_domain(domain)
      subject
    end
  end
end
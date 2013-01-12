require 'spec_helper'

describe VMC::Domain::Map do
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

  subject { invoke_cli(cli, :map_domain, inputs, given, global) }

  shared_examples "binding a domain to a space" do
    it "adds the domain to the space's organization" do
      mock(space.organization).add_domain(domain)
      stub(space).add_domain(domain)
      subject
    end

    it 'adds the domain to the space' do
      stub(space.organization).add_domain(domain)
      mock(space).add_domain(domain)
      subject
    end
  end

  shared_examples "binding a domain to an organization" do
    it 'does NOT add the domain to a space' do
      any_instance_of(space.class) do |space|
        dont_allow(space).add_domain(domain)
      end
    end

    it 'adds the domain to the organization' do
      mock(organization).add_domain(domain)
      subject
    end
  end

  shared_examples "mapping a domain to a space" do
    context "when the domain does NOT exist" do
      before do
        stub(client).domain { domain }
        stub(domain).create!
        stub(space.organization).add_domain(domain)
        stub(space).add_domain(domain)
      end

      it 'creates the domain' do
        mock(domain).create!
        subject
        expect(domain.name).to eq domain_name
        expect(domain.owning_organization).to eq organization
      end

      include_examples "binding a domain to a space"
    end

    context "when the domain already exists" do
      let(:client) {
        fake_client :domains => [domain],
                    :current_organization => organization,
                    :current_space => space
      }

      include_examples "binding a domain to a space"
    end
  end

  context 'when a domain and a space are passed' do
    let(:inputs) { { :space => space, :name => domain_name } }

    include_examples "mapping a domain to a space"
  end

  context 'when a domain and an organization are passed' do
    let(:inputs) { { :organization => organization, :name => domain_name } }

    context "and the domain does NOT exist" do
      before do
        stub(client).domain { domain }
        stub(domain).create!
        stub(organization).add_domain(domain)
      end

      include_examples "binding a domain to an organization"

      it 'adds the domain to the organization' do
        mock(organization).add_domain(domain)
        subject
      end

      context "and the --shared option is passed" do
        let(:inputs) { { :organization => organization, :name => domain_name, :shared => true } }

        it 'adds the domain to the organization' do
          mock(domain).create!
          subject
          expect(domain.name).to eq domain_name
        end

        it "does not add the domain to a specific organization" do
          stub(domain).create!
          subject
          expect(domain.owning_organization).to be_nil
        end
      end
    end

    context "and the domain already exists" do
      let(:client) {
        fake_client :domains => [domain],
                    :current_organization => organization,
                    :current_space => space
      }

      include_examples "binding a domain to an organization"
    end
  end

  context 'when a domain, organization, and space is passed' do
    let(:inputs) { { :name => domain_name, :organization => organization, :space => space } }

    include_examples "mapping a domain to a space"
  end

  context 'when only a domain is passed' do
    let(:inputs) { { :name => domain_name } }

    include_examples "mapping a domain to a space"
  end
end
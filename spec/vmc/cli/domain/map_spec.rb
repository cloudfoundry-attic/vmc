require 'spec_helper'

command VMC::Domain::Map do
  let(:client) do
    fake_client(
      :current_organization => organization,
      :current_space => space,
      :spaces => [space],
      :organizations => [organization],
      :domains => domains)
  end

  let(:organization) { fake(:organization) }
  let(:space) { fake(:space, :organization => organization) }
  let(:domain) { fake(:domain, :name => domain_name) }
  let(:domain_name) { "some.domain.com" }
  let(:domains) { [domain] }

  shared_examples_for "binding a domain to a space" do
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

  shared_examples_for "binding a domain to an organization" do
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

  shared_examples_for "mapping a domain to a space" do
    context "when the domain does NOT exist" do
      let(:domains) { [] }

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
      include_examples "binding a domain to a space"
    end
  end

  context 'when a domain and a space are passed' do
    subject { vmc %W[map-domain #{domain.name} --space #{space.name}] }

    include_examples "mapping a domain to a space"
  end

  context 'when a domain and an organization are passed' do
    subject { vmc %W[map-domain #{domain.name} --organization #{organization.name}] }

    context "and the domain does NOT exist" do
      let(:domains) { [] }

      before do
        stub(client).domain { domain }
        stub(domain).create!
        stub(organization).add_domain(domain)
      end

      include_examples "binding a domain to an organization"

      it 'creates the domain' do
        mock(domain).create!
        subject
        expect(domain.name).to eq domain_name
      end

      context "and the --shared option is passed" do
        subject { vmc %W[map-domain #{domain.name} --organization #{organization.name} --shared] }

        it 'adds the domain to the organization' do
          mock(organization).add_domain(domain)
          subject
        end

        it "does not add the domain to a specific organization" do
          stub(domain).create!
          subject
          expect(domain.owning_organization).to be_nil
        end
      end
    end

    context "and the domain already exists" do
      include_examples "binding a domain to an organization"
    end
  end

  context 'when a domain, organization, and space is passed' do
    subject { vmc %W[map-domain #{domain.name} --space #{space.name} --organization #{organization.name}] }

    include_examples "mapping a domain to a space"
  end

  context 'when only a domain is passed' do
    subject { vmc %W[map-domain #{domain.name}] }

    include_examples "mapping a domain to a space"
  end
end

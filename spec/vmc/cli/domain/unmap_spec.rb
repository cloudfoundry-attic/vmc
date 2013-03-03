require 'spec_helper'

command VMC::Domain::Unmap do
  let(:client) do
    fake_client(
      :current_organization => organization,
      :current_space => space,
      :spaces => [space],
      :organizations => [organization],
      :domains => [domain])
  end

  let(:organization) { fake(:organization, :spaces => [space]) }
  let(:space) { fake(:space) }
  let(:domain) { fake(:domain, :name => "some.domain.com") }

  context "when the --delete flag is given" do
    subject { vmc %W[unmap-domain #{domain.name} --delete] }

    it "asks for a confirmation" do
      mock_ask("Really delete #{domain.name}?", :default => false) { false }
      stub(domain).delete!
      subject
    end

    context "and the user answers 'no' to the confirmation" do
      it "does NOT delete the domain" do
        stub_ask("Really delete #{domain.name}?", anything) { false }
        dont_allow(domain).delete!
        subject
      end
    end

    context "and the user answers 'yes' to the confirmation" do
      it "deletes the domain" do
        stub_ask("Really delete #{domain.name}?", anything) { true }
        mock(domain).delete!
        subject
      end
    end
  end

  context "when a space is given" do
    subject { vmc %W[unmap-domain #{domain.name} --space #{space.name}] }

    it "unmaps the domain from the space" do
      mock(space).remove_domain(domain)
      subject
    end
  end

  context "when an organization is given" do
    subject { vmc %W[unmap-domain #{domain.name} --organization #{organization.name}] }

    it "unmaps the domain from the organization" do
      mock(organization).remove_domain(domain)
      subject
    end
  end

  context "when only the domain is given" do
    subject { vmc %W[unmap-domain #{domain.name}] }

    it "unmaps the domain from the current space" do
      mock(client.current_space).remove_domain(domain)
      subject
    end
  end
end

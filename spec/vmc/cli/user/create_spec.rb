require 'spec_helper'

describe VMC::User::Create do
  let(:client) { fake_client }

  before do
    any_instance_of(described_class) { |cli| stub(cli).client { client } }
    stub(client).register
  end

  subject { vmc %W[create-user --#{bool_flag(:force)}] }

  context "when the user is not logged in" do
    let(:force) { true }

    before do
      stub(client).logged_in? { false }
    end

    it "tells the user to log in" do
      subject
      expect(stderr.string).to include("Please log in")
    end
  end

  context "when the user is logged in" do
    let(:force) { false }

    before do
      stub(client).logged_in? { true }
      stub_ask("Email") { "some-angry-dude@example.com" }
      stub_ask("Password", anything) { "password1" }
      stub_ask("Verify Password", anything) { confirmation }
    end

    context "when the password does not match its confirmation" do
      let(:confirmation) { "wrong" }

      it "displays an error message" do
        subject
        expect(stderr.string).to include("Passwords don't match")
      end
    end

    context "when the password matches its confirmation" do
      let(:confirmation) { "password1" }

      it "creates a user" do
        mock(client).register("some-angry-dude@example.com", "password1")
        subject
      end
    end
  end
end
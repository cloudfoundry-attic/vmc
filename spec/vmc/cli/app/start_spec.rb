require "spec_helper"
require "webmock/rspec"

command VMC::App::Start do
  let(:client) { fake_client :apps => [app] }
  let(:app) { fake :app }

  subject { vmc %W[start #{app.name}] }

  context "with an app that's already started" do
    let(:app) { fake :app, :state => "STARTED" }

    it "skips starting the application" do
      dont_allow(app).start!
      subject
    end

    it "says the app is already started" do
      subject
      expect(error_output).to say("Application #{app.name} is already started.")
    end
  end

  context "with an app that's NOT already started" do
    def self.it_says_application_is_starting
      it "says that it's starting the application" do
        subject
        expect(output).to say("Starting #{app.name}... OK")
      end
    end

    def self.it_prints_log_progress
      it "prints out the log progress" do
        subject
        expect(output).to say(log_text)
      end
    end

    def self.it_does_not_print_log_progress
      it "does not print the log progress" do
        subject
        expect(output).to_not say(log_text)
      end
    end

    def self.it_waits_for_application_to_become_healthy
      describe "waits for application to become healthy" do
        let(:app) { fake :app, :total_instances => 2 }

        def after_sleep
          any_instance_of described_class do |cli|
            stub(cli).sleep { yield }
          end
        end

        before do
          stub(app).instances do
            [ CFoundry::V2::App::Instance.new(nil, nil, nil, :state => "DOWN"),
              CFoundry::V2::App::Instance.new(nil, nil, nil, :state => "RUNNING")
            ]
          end

          after_sleep do
            stub(app).instances { final_instances }
          end
        end

        context "when all instances become running" do
          let(:final_instances) do
            [ CFoundry::V2::App::Instance.new(nil, nil, nil, :state => "RUNNING"),
              CFoundry::V2::App::Instance.new(nil, nil, nil, :state => "RUNNING")
            ]
          end

          it "says app is started" do
            subject
            expect(output).to say("Checking #{app.name}...")
            expect(output).to say("1 running, 1 down")
            expect(output).to say("2 running")
          end
        end

        context "when any instance becomes flapping" do
          let(:final_instances) do
            [ CFoundry::V2::App::Instance.new(nil, nil, nil, :state => "FLAPPING"),
              CFoundry::V2::App::Instance.new(nil, nil, nil, :state => "STARTING")
            ]
          end

          it "says app failed to start" do
            subject
            expect(output).to say("Checking #{app.name}...")
            expect(output).to say("1 running, 1 down")
            expect(output).to say("1 starting, 1 flapping")
            expect(error_output).to say("Application failed to start")
          end
        end
      end
    end

    before do
      stub(app).invalidate!
      stub(app).instances do
        [ CFoundry::V2::App::Instance.new(nil, nil, nil, :state => "RUNNING") ]
      end

      stub(app).start!(true) do |_, blk|
        app.state = "STARTED"
        blk.call(log_url)
      end
    end

    context "when progress log url is provided" do
      let(:log_url) { "http://example.com/my-app-log" }
      let(:log_text) { "Staging complete!" }

      context "and progress log url is not available immediately" do
        before do
          stub_request(:get, "#{log_url}&tail&tail_offset=0").to_return(
            :status => 404, :body => "")
        end
        
        it_says_application_is_starting
        it_does_not_print_log_progress
        it_waits_for_application_to_become_healthy
      end

      context "and progress log url becomes unavailable after some time" do
        before do 
          stub_request(:get, "#{log_url}&tail&tail_offset=0").to_return(
            :status => 200, :body => log_text[0...5])
          stub_request(:get, "#{log_url}&tail&tail_offset=5").to_return(
            :status => 200, :body => log_text[5..-1])
          stub_request(:get, "#{log_url}&tail&tail_offset=#{log_text.size}").to_return(
            :status => 404, :body => "")
        end

        it_says_application_is_starting
        it_prints_log_progress
        it_waits_for_application_to_become_healthy
      end

      context "and a request times out" do
        before do 
          stub_request(:get, "#{log_url}&tail&tail_offset=0").to_return(
            :should_timeout => true)
          stub_request(:get, "#{log_url}&tail&tail_offset=0").to_return(
            :status => 200, :body => log_text)
          stub_request(:get, "#{log_url}&tail&tail_offset=#{log_text.size}").to_return(
            :status => 404, :body => "")
        end

        it_says_application_is_starting
        it_prints_log_progress
        it_waits_for_application_to_become_healthy
      end
    end

    context "when progress log url is not provided" do
      let(:log_url) { nil }
      let(:log_text) { "Staging complete!" }

      it_says_application_is_starting
      it_does_not_print_log_progress
      it_waits_for_application_to_become_healthy
    end
  end
end

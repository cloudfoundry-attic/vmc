require 'spec_helper'

describe VMC::Detector do
  let(:client) { fake_client :frameworks => [framework] }
  let(:detector) { VMC::Detector.new client, nil }

  describe '#detect_framework' do
    subject { detector.detect_framework }

    { Clouseau::Django => "django",
      Clouseau::DotNet => "dotNet",
      Clouseau::Grails => "grails",
      Clouseau::Java => "java_web",
      Clouseau::Lift => "lift",
      Clouseau::Node => "node",
      Clouseau::PHP => "php",
      Clouseau::Play => "play",
      Clouseau::Python => "wsgi",
      Clouseau::Rack => "rack",
      Clouseau::Rails => "rails3",
      Clouseau::Sinatra => "sinatra",
      Clouseau::Spring => "spring"
    }.each do |clouseau_detective, cf_name|
      context "when we detected #{clouseau_detective}" do
        let(:framework) { fake(:framework, :name => cf_name) }

        it "maps to CF name #{cf_name}" do
          stub(Clouseau).detect(anything) { clouseau_detective }
          should eq framework
        end
      end
    end
  end

  describe '#detect_runtime' do

  end

  describe '#runtimes' do

  end

  describe '#suggested_memory' do

  end

  describe '#all_runtimes' do

  end

  describe '#all_frameworks' do

  end
end

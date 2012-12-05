FactoryGirl.define do
  factory :client, :class => CFoundry::V2::Client do
    ignore do
      routes []
      apps []
      frameworks []
      runtimes []
      service_instances []
      spaces []
      organizations []
      logged_in true
    end

    after_build do |client, evaluator|
      RR.stub(client).logged_in? { evaluator.logged_in }
      RR.stub(client).routes { evaluator.routes }
      RR.stub(client).apps { evaluator.apps }
      RR.stub(client).frameworks { evaluator.frameworks }
      RR.stub(client).runtimes { evaluator.runtimes }
      RR.stub(client).service_instances { evaluator.service_instances }
      RR.stub(client).spaces { evaluator.spaces }
      RR.stub(client).organizations { evaluator.organizations }
    end
  end
end

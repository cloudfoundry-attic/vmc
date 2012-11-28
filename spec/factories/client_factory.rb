FactoryGirl.define do
  factory :client, :class => CFoundry::V2::Client do
    ignore do
      routes []
      apps []
      frameworks []
    end

    after_build do |client, evaluator|
      RR.stub(client).logged_in? { true }
      RR.stub(client).routes { evaluator.routes }
      RR.stub(client).apps { evaluator.apps }
      RR.stub(client).frameworks { evaluator.frameworks }
    end
  end
end

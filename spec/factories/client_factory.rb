FactoryGirl.define do
  factory :client, :class => CFoundry::V2::Client do
    ignore do
      routes []
      apps []
    end

    after_build do |client, evaluator|
      RR.stub(client).logged_in? { true }
      RR.stub(client).routes { evaluator.routes }
      RR.stub(client).apps { evaluator.apps }
    end
  end
end

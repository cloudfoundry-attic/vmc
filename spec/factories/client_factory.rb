FactoryGirl.define do
  factory :client, :class => CFoundry::V2::Client do
    ignore do
      routes []
    end

    after_build do |client, evaluator|
      RR.stub(client).logged_in? { true }
      RR.stub(client).routes { evaluator.routes }
    end
  end
end
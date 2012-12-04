FactoryGirl.define do
  factory :runtime, :class => CFoundry::V2::Runtime do
    name { FactoryGirl.generate(:random_string) }
    guid { FactoryGirl.generate(:guid) }

    initialize_with do
      CFoundry::V2::Runtime.new(nil, nil)
    end
  end
end

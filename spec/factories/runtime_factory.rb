FactoryGirl.define do
  factory :runtime, :class => CFoundry::V2::Runtime do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }

    initialize_with do
      CFoundry::V2::Runtime.new(nil, nil)
    end
  end
end

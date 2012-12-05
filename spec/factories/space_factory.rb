FactoryGirl.define do
  factory :space, :class => CFoundry::V2::Space do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }

    initialize_with do
      CFoundry::V2::Space.new(nil, nil)
    end
  end
end

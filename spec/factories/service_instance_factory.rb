FactoryGirl.define do
  factory :service_instance, :class => CFoundry::V2::ServiceInstance do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }

    initialize_with do
      CFoundry::V2::ServiceInstance.new(nil, nil)
    end
  end
end

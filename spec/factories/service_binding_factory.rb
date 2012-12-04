FactoryGirl.define do
  factory :service_binding, :class => CFoundry::V2::ServiceBinding do
    guid { FactoryGirl.generate(:guid) }

    initialize_with do
      CFoundry::V2::ServiceBinding.new(nil, nil)
    end
  end
end

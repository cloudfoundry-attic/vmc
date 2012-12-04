FactoryGirl.define do
  factory :service_plan, :class => CFoundry::V2::ServicePlan do
    guid { FactoryGirl.generate(:guid) }
    name "D100"
    description "Filibuster plan"

    initialize_with do
      CFoundry::V2::ServicePlan.new(nil, nil)
    end
  end
end

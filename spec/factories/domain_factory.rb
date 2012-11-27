FactoryGirl.define do
  factory :domain, :class => CFoundry::V2::Domain do
    name { FactoryGirl.generate(:random_string) }

    initialize_with do
      CFoundry::V2::Domain.new(nil, nil)
    end
  end
end
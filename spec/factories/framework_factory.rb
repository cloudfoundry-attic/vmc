FactoryGirl.define do
  factory :framework, :class => CFoundry::V2::Framework do
    name { FactoryGirl.generate(:random_string) }

    initialize_with do
      CFoundry::V2::Framework.new(nil, nil)
    end
  end
end

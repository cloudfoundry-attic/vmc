FactoryGirl.define do
  factory :route, :class => CFoundry::V2::Route do
    host { FactoryGirl.generate(:random_string) }
    association :domain, :factory => :domain, :strategy => :build

    initialize_with do
      CFoundry::V2::Route.new(nil, nil)
    end
  end
end

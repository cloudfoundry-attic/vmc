FactoryGirl.define do
  factory :app, :class => CFoundry::V2::App do
    name { FactoryGirl.generate(:random_string) }

    initialize_with do
      CFoundry::V2::App.new(nil, nil)
    end
  end
end

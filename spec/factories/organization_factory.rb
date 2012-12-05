FactoryGirl.define do
  factory :organization, :class => CFoundry::V2::Organization do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }

    ignore do
      spaces []
    end

    initialize_with do
      CFoundry::V2::Organization.new(nil, nil)
    end

    after_build do |org, evaluator|
      RR.stub(org).spaces { evaluator.spaces }
    end
  end
end

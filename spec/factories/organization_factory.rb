FactoryGirl.define do
  factory :organization, :class => CFoundry::V2::Organization do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }

    ignore do
      spaces []
      domains []
    end

    initialize_with do
      CFoundry::V2::Organization.new(nil, nil)
    end

    after_build do |org, evaluator|
      evaluator.spaces.each { |s| s.organization = org }
      evaluator.domains.each { |s| s.owning_organization = org }

      RR.stub(org).spaces { evaluator.spaces }
      RR.stub(org).domains { evaluator.domains }
    end
  end
end

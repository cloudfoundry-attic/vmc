FactoryGirl.define do
  factory :space, :class => CFoundry::V2::Space do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }

    ignore do
      apps []
      service_instances []
      domains []
    end

    initialize_with do
      CFoundry::V2::Space.new(nil, nil)
    end

    after_build do |org, evaluator|
      evaluator.apps.each { |s| s.space = org }
      evaluator.service_instances.each { |s| s.space = org }

      RR.stub(org).apps { evaluator.apps }
      RR.stub(org).service_instances { evaluator.service_instances }
      RR.stub(org).domains { evaluator.domains }
    end
  end
end

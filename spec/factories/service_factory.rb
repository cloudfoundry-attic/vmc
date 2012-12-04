FactoryGirl.define do
  factory :service, :class => CFoundry::V2::Service do
    guid { FactoryGirl.generate(:guid) }
    label "redis"
    provider "core"
    url "http://example.com"
    description "small key-value store"
    version "2.8"
    info_url "http://cloudfoundry.com/redis"
    active true

    initialize_with do
      CFoundry::V2::Service.new(nil, nil)
    end
  end
end


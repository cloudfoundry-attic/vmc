FactoryGirl.define do
  sequence(:random_string) {|n| "random_#{n}_string" }
  sequence(:guid) {|n| "random_#{n}_guid" }
end

# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:auth0_sub) { |n| "auth0|test#{n.to_s.rjust(6, '0')}" }
    sequence(:email)     { |n| "user#{n}@solarpeak.test" }
    role                 { 'viewer' }
    query_limit_days     { 30 }
    active               { true }

    trait :viewer  do role { 'viewer'  } end
    trait :manager do role { 'manager' } end
    trait :admin   do role { 'admin'   } ; query_limit_days { 365 } end

    trait :inactive do active { false } end

    trait :unlimited do query_limit_days { 365 } end
  end
end

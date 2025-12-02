# frozen_string_literal: true

FactoryBot.define do
  factory :access_code, class: AccessCode do
    sequence(:code) { |n| "code#{n}" }
  end
end

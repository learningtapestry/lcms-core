# frozen_string_literal: true

FactoryBot.define do
  factory :setting do
    sequence(:key) { |n| "setting_key_#{n}" }
    value { "setting_value" }
  end
end

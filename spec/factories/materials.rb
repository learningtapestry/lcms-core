# frozen_string_literal: true

FactoryBot.define do
  factory :material, class: Material do
    sequence(:identifier, "a") { |n| n }
    file_id { "file_#{SecureRandom.hex(6)}" }
  end
end

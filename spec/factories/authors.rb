# frozen_string_literal: true

FactoryBot.define do
  factory :author, class: Author do
    name { 'Great Minds' }
    slug { 'great-minds' }
  end
end

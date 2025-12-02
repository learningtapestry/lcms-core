# frozen_string_literal: true

FactoryBot.define do
  factory :curriculum, class: Curriculum do
    name { 'EngageNY' }
    slug { 'engageny' }
    default { true }
  end
end

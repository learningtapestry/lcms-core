# frozen_string_literal: true

FactoryBot.define do
  factory :resource, class: Resource do
    curriculum { Curriculum.default || create(:curriculum) }
    curriculum_type { "lesson" }
    metadata do
      { subject: "math", grade: "grade 2", unit: "unit 1",
        section: "section 1", lesson: "lesson 1" }
    end
    title { "Test Resource" }
    tree { true }
    url { "Resource URL" }

    trait :grade do
      curriculum_type { "grade" }
      metadata { { subject: "math", grade: "grade 2" } }
    end

    trait :unit do
      curriculum_type { "unit" }
      metadata { { subject: "math", grade: "grade 2", unit: "unit 1" } }
    end
  end
end

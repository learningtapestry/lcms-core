# frozen_string_literal: true

# == Schema Information
#
# Table name: resources
#
#  id                    :integer          not null, primary key
#  curriculum_type       :string
#  deleted_at            :datetime
#  description           :string
#  hidden                :boolean          default(FALSE)
#  hierarchical_position :string
#  image_file            :string
#  indexed_at            :datetime
#  level_position        :integer
#  links                 :jsonb
#  metadata              :jsonb            not null
#  short_title           :string
#  slug                  :string
#  subtitle              :string
#  teaser                :string
#  title                 :string
#  tree                  :boolean          default(FALSE), not null
#  url                   :string
#  created_at            :datetime
#  updated_at            :datetime
#  author_id             :integer
#  curriculum_id         :integer
#  parent_id             :integer
#
# Indexes
#
#  index_resources_on_author_id      (author_id)
#  index_resources_on_curriculum_id  (curriculum_id)
#  index_resources_on_deleted_at     (deleted_at)
#  index_resources_on_indexed_at     (indexed_at)
#  index_resources_on_metadata       (metadata) USING gin
#
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

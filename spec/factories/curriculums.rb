# frozen_string_literal: true

# == Schema Information
#
# Table name: curriculums
#
#  id         :integer          not null, primary key
#  default    :boolean          default(FALSE), not null
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :curriculum, class: Curriculum do
    name { "EngageNY" }
    slug { "engageny" }
    default { true }
  end
end

# frozen_string_literal: true

# == Schema Information
#
# Table name: authors
#
#  id         :integer          not null, primary key
#  name       :string
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :author, class: Author do
    name { "Great Minds" }
    slug { "great-minds" }
  end
end

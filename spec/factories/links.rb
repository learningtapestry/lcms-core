# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id         :bigint           not null, primary key
#  identifier :string           not null
#  text       :text
#  url        :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_links_on_identifier  (identifier) UNIQUE
#
FactoryBot.define do
  factory :link do
    sequence(:identifier) { |n| "url#{n}" }
    sequence(:url) { |n| "https://example.com/page-#{n}" }
    text { nil }
  end
end

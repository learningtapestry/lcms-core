# frozen_string_literal: true

# == Schema Information
#
# Table name: images
#
#  id         :bigint           not null, primary key
#  alt_text   :text
#  caption    :text
#  credit     :text
#  file_url   :string           not null
#  identifier :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_images_on_identifier  (identifier) UNIQUE
#
FactoryBot.define do
  factory :image do
    sequence(:identifier) { |n| "img#{n}" }
    sequence(:file_url) { |n| "https://bucket.s3.us-east-1.amazonaws.com/images/image-#{n}.jpg" }
    caption { "Image of a mountain scene." }
    credit { "Used with permission from Ten Strands." }
    alt_text { "A turquoise lake between forested mountains" }
  end
end

# frozen_string_literal: true

# == Schema Information
#
# Table name: materials
#
#  id                :integer          not null, primary key
#  css_styles        :text
#  identifier        :string
#  last_author_email :string
#  last_author_name  :string
#  last_modified_at  :datetime
#  links             :jsonb
#  metadata          :jsonb            not null
#  name              :string
#  original_content  :text
#  preview_links     :jsonb
#  reimported_at     :datetime
#  version           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  file_id           :string           not null
#
# Indexes
#
#  index_materials_on_file_id     (file_id)
#  index_materials_on_identifier  (identifier)
#  index_materials_on_metadata    (metadata) USING gin
#
FactoryBot.define do
  factory :material, class: Material do
    sequence(:identifier, "a") { |n| n }
    file_id { "file_#{SecureRandom.hex(6)}" }
  end
end

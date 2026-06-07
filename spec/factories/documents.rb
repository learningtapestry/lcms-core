# frozen_string_literal: true

# == Schema Information
#
# Table name: documents
#
#  id                :integer          not null, primary key
#  active            :boolean          default(TRUE), not null
#  activity_metadata :jsonb
#  agenda_metadata   :jsonb
#  css_styles        :text
#  last_author_email :string
#  last_author_name  :string
#  last_modified_at  :datetime
#  links             :jsonb            not null
#  metadata          :jsonb            not null
#  name              :string
#  original_content  :text
#  preview_links     :jsonb
#  reimported        :boolean          default(TRUE), not null
#  reimported_at     :datetime
#  sections_metadata :jsonb
#  version           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  file_id           :string
#  resource_id       :integer
#
# Indexes
#
#  index_documents_on_file_id      (file_id)
#  index_documents_on_metadata     (metadata) USING gin
#  index_documents_on_resource_id  (resource_id)
#
FactoryBot.define do
  factory :document, class: Document do
    file_id { "file_#{SecureRandom.hex(6)}" }
  end
end

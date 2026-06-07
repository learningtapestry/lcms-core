# frozen_string_literal: true

# == Schema Information
#
# Table name: document_parts
#
#  id            :integer          not null, primary key
#  active        :boolean
#  anchor        :string
#  content       :text
#  context_type  :integer          default("default")
#  data          :jsonb            not null
#  materials     :text             default([]), not null, is an Array
#  optional      :boolean          default(FALSE), not null
#  part_type     :string
#  placeholder   :string
#  renderer_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  renderer_id   :integer
#
# Indexes
#
#  index_document_parts_on_anchor                         (anchor)
#  index_document_parts_on_context_type                   (context_type)
#  index_document_parts_on_placeholder                    (placeholder)
#  index_document_parts_on_renderer_type_and_renderer_id  (renderer_type,renderer_id)
#
FactoryBot.define do
  factory :document_part, class: DocumentPart do
    renderer { nil }
    content { "MyText" }
    part_type { "layout" }
    active { true }
  end
end

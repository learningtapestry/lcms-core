# frozen_string_literal: true

FactoryBot.define do
  factory :document_part, class: DocumentPart do
    renderer { nil }
    content { "MyText" }
    part_type { "layout" }
    active { true }
  end
end

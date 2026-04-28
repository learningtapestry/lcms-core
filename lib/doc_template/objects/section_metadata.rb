# frozen_string_literal: true

module DocTemplate
  module Objects
    class SectionMetadata < Base
      attribute :description, :string, default: ""
      attribute :grade, :string, default: ""
      attribute :material_ids, :json_array, default: -> { [] }
      attribute :section_materials, :string, default: ""
      attribute :section_number, :string, default: ""
      attribute :section_title, :string, default: ""
      attribute :section_title_spanish, :string, default: ""
      attribute :unit_id, :string, default: ""
    end
  end
end

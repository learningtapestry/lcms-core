# frozen_string_literal: true

module DocTemplate
  module Objects
    class Unit < Base
      attribute :acknowledgements, :string, default: ""
      attribute :copyright, :string, default: ""
      attribute :course, :string, default: ""
      attribute :description, :string, default: ""
      attribute :grade, :string, default: ""
      attribute :license, :string, default: ""
      attribute :material_ids, :json_array, default: -> { [] }
      attribute :unit_id, :string, default: ""
      attribute :unit_materials, :string, default: ""
      attribute :unit_title, :string, default: ""
      attribute :unit_title_spanish, :string, default: ""
      attribute :unit_topic, :string, default: ""
      attribute :unit_topic_spanish, :string, default: ""
    end
  end
end

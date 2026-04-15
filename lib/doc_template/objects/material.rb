# frozen_string_literal: true

module DocTemplate
  module Objects
    class Material < Base
      ORIENTATIONS = {
        l: "landscape",
        landscape: "landscape",
        p: "portrait",
        portrait: "portrait"
      }.freeze

      attribute :attribution, :string, default: ""
      attribute :grade, :string, default: ""
      attribute :language, :string, default: ""
      attribute :material_id, :string, default: ""
      attribute :material_order, :integer, default: 0
      attribute :material_title, :string, default: ""
      attribute :material_title_spanish, :string, default: ""
      attribute :material_type, :string, default: ""
      attribute :name_date, :boolean, default: false
      attribute :orientation, :string, default: "p"

      class << self
        #
        # @param [Hash{String | Symbol->Unknown}] data
        # @return [DocTemplate::Objects::Material]
        #
        def build_from(data)
          data = prepare_data data
          data["material_order"] = 0 if data["material_order"].blank?
          data["name_date"] = false if data["name_date"].nil?
          data["orientation"] = handle_orientation data["orientation"]

          new data
        end

        private

        #
        # @param [String] orientation
        # @return [String (frozen)]
        #
        def handle_orientation(orientation)
          ORIENTATIONS[orientation.to_s.downcase.to_sym] || ORIENTATIONS[:p]
        end
      end
    end
  end
end

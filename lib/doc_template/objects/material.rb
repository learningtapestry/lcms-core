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

      attribute :activity, Integer
      attribute :cc_attribution, String, default: ""
      attribute :grade, String, default: ""
      attribute :header_footer, String, default: "yes"
      attribute :identifier, String, default: ""
      attribute :lesson, String, default: ""
      attribute :name_date, String, default: "no"
      attribute :orientation, String, default: ->(_, attr) { attr.blank? ? "p" : attr }
      attribute :section, String, default: ""
      attribute :show_title, String, default: "yes"
      attribute :title, String, default: ""
      attribute :type, String, default: ""
      attribute :unit, String, default: ""

      class << self
        #
        # @param [Hash{String | Symbol->Unknown}] data
        # @return [Dese::Lcms::Metadata::Objects::Material]
        #
        def build_from(data)
          data = prepare_data data
          raise "Type field is empty. Material should have a type." if data["type"].blank?

          data["orientation"] = handle_orientation data["orientation"]

          new data
        end

        private

        #
        # @param [String] orientation
        # @return [String (frozen)]
        #
        def handle_orientation(orientation)
          ORIENTATIONS[orientation.downcase.to_sym] || ORIENTATIONS[:p]
        end
      end
    end
  end
end

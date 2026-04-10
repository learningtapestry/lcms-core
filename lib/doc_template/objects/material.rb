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

      attribute :activity, :integer
      attribute :cc_attribution, :string, default: ""
      attribute :grade, :string, default: ""
      attribute :header_footer, :string, default: "yes"
      attribute :identifier, :string, default: ""
      attribute :lesson, :string, default: ""
      attribute :name_date, :string, default: "no"
      attribute :orientation, :string, default: "p"
      attribute :section, :string, default: ""
      attribute :show_title, :string, default: "yes"
      attribute :title, :string, default: ""
      attribute :type, :string, default: ""
      attribute :unit, :string, default: ""

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

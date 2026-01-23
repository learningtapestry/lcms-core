# frozen_string_literal: true

module DocTemplate
  module Objects
    class Material < Base
      attribute :activity, Integer
      attribute :cc_attribution, String, default: ""
      attribute :grade, String, default: ""
      attribute :header_footer, String, default: "yes"
      attribute :identifier, String, default: ""
      attribute :lesson, String, default: ""
      attribute :module, String, default: ""
      attribute :name_date, String, default: "no"
      attribute :orientation, String
      attribute :show_title, String, default: "yes"
      attribute :title, String, default: ""
      attribute :type, String, default: ""
      attribute :unit, String, default: ""
    end
  end
end

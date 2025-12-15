# frozen_string_literal: true

module DocTemplate
  module Objects
    class Material < Base
      attribute :activity, Integer
      attribute :cc_attribution, String, default: ""
      attribute :grade, Integer
      attribute :header_footer, String, default: "yes"
      attribute :identifier, String, default: ""
      attribute :lesson, Integer
      attribute :name_date, String, default: "no"
      attribute :orientation, String
      attribute :section, Integer
      attribute :show_title, String, default: "yes"
      attribute :title, String, default: ""
      attribute :type, String, default: ""
    end
  end
end

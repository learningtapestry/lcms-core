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
      attribute :pdf_url, String
      attribute :preserve_table_padding, String, default: "no"
      attribute :section, Integer
      attribute :show_title, String, default: "yes"
      attribute :title, String, default: ""
      attribute :thumb_url, String
      attribute :type, String, default: "default"
    end
  end
end

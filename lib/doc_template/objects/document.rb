# frozen_string_literal: true

module DocTemplate
  module Objects
    class Document < Base
      attribute :cc_attribution, String, default: ""
      attribute :description, String, default: ""
      attribute :grade, String, default: ""
      attribute :lesson, String, default: ""
      attribute :lesson_objective, String, default: ""
      attribute :lesson_standard, String, default: ""
      attribute :materials, String, default: ""
      attribute :module, String, default: ""
      attribute :preparation, String, default: ""
      attribute :standard, String, default: ""
      attribute :teaser, String, default: ""
      attribute :title, String, default: ""
      attribute :topic, String, default: ""
      attribute :type, String, default: "core"
      attribute :unit, String, default: ""
    end
  end
end

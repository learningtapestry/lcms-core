# frozen_string_literal: true

module DocTemplate
  module Objects
    class Document < Base
      attribute :cc_attribution, :string, default: ""
      attribute :description, :string, default: ""
      attribute :grade, :string, default: ""
      attribute :lesson, :string, default: ""
      attribute :lesson_objective, :string, default: ""
      attribute :lesson_standard, :string, default: ""
      attribute :materials, :string, default: ""
      attribute :preparation, :string, default: ""
      attribute :section, :string, default: ""
      attribute :standard, :string, default: ""
      attribute :teaser, :string, default: ""
      attribute :title, :string, default: ""
      attribute :type, :string, default: "core"
      attribute :unit, :string, default: ""
    end
  end
end

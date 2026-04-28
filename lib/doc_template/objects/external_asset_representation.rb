# frozen_string_literal: true

module DocTemplate
  module Objects
    class ExternalAssetRepresentation < Base
      attribute :pdf, :string, default: ""
      attribute :doc, :string, default: ""
      attribute :slides, :string, default: ""
      attribute :sheet, :string, default: ""
      attribute :form, :string, default: ""
      attribute :video, :string, default: ""
      attribute :webpage, :string, default: ""
    end
  end
end

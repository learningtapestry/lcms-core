# frozen_string_literal: true

module Admin
  module DocumentsHelper
    def material_urls(material, doc)
      lesson = DocumentGenerator.document_presenter.new(doc)
      presenter = DocumentGenerator.material_presenter.new(material, lesson:)
      { pdf: presenter.pdf_url, gdoc: presenter.gdoc_url }
    end
  end
end

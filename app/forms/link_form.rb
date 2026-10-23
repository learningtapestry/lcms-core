# frozen_string_literal: true

class LinkForm < ImportForm
  def save
    super { LinksImportService.call link }
  end
end

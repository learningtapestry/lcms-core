# frozen_string_literal: true

class StandardForm < ImportForm
  def save
    super { StandardsImportService.call link }
  end
end

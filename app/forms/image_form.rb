# frozen_string_literal: true

class ImageForm < ImportForm
  def save
    super { ImagesImportService.call link }
  end
end

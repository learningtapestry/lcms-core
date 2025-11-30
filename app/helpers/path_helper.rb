# frozen_string_literal: true

module PathHelper
  def dynamic_path(path, *)
    send(path.to_sym, *)
  end

  def dynamic_document_path(*)
    document_path(*)
  end

  def dynamic_material_path(*)
    material_path(*)
  end
end

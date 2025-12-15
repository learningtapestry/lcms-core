# frozen_string_literal: true

class MaterialsController < Admin::AdminController
  before_action :set_material

  def preview_pdf
    if (url = @material.preview_links["pdf"]).present?
      return redirect_to url
    end

    preview_for :pdf
  end

  def preview_gdoc
    if (url = @material.preview_links["gdoc"]).present? && url !~ MaterialPreviewGenerator::GDOC_BROKEN_RE
      return redirect_to url
    end

    preview_for :gdoc, folder_id: ENV.fetch("GOOGLE_APPLICATION_PREVIEW_FOLDER_ID")
  end

  def show; end

  private

  def preview_for(preview_type, options = {})
    service = MaterialPreviewGenerator.new @material, options.merge(type: preview_type)
    if service.perform
      links = @material.preview_links
      @material.update preview_links: links.merge(preview_type => service.url)
      redirect_to service.url
    else
      redirect_to material_path(@material), notice: service.error
    end
  end

  def set_material
    @material = DocumentGenerator.material_presenter.new(Material.find params[:id])
  end
end

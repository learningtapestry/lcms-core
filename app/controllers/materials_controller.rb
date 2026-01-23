# frozen_string_literal: true

class MaterialsController < Admin::AdminController
  include ErrorMessage

  before_action :set_material

  def preview_pdf
    key = "pdf"

    if !ENV.fetch("FORCE_PREVIEW_GENERATION", false) && (url = @material.preview_links[key]).present?
      return redirect_to url
    end

    job_options = {
      folder: ENV.fetch("AWS_S3_PREVIEW_FOLDER", "previews"),
      preview: true
    }
    MaterialPdfJob.perform_now(@material.id, job_options)

    redirect_to @material.reload.preview_links.dig(key, "url"), allow_other_host: true
  rescue StandardError => e
    redirect_to material_path(@material), alert: error_message_for(e)
  end

  def preview_gdoc
    raise NotImpementedError
    # if !ENV.fetch("FORCE_PREVIEW_GENERATION", false) &&  (url = @material.preview_links["gdoc"]).present?
    #   return redirect_to url
    # end
  end

  def show; end

  private

  def set_material
    @material = MaterialPresenter.new(Material.find params[:id])
  end
end

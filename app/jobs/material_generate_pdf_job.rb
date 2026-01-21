# frozen_string_literal: true

class MaterialGeneratePdfJob < ApplicationJob
  include ResqueJob

  include RetrySimple

  queue_as :default

  def perform(entry_id, document)
    material = Material.find(entry_id)
    material_links = links_from_upload(material, document)

    new_links = {
      "materials" => {
        material.id.to_s => material_links
      }
    }

    document.with_lock do
      links = document.reload.links
      document.update links: links.deep_merge(new_links)
    end

    DocumentGenerateJob.perform_later(document.id, check_queue: true)
  end

  private

  def links_from_upload(material, document)
    material = material_presenter(material, document)

    basename = "#{::DocumentExporter::Pdf::Base.s3_folder}/#{material.pdf_filename}"
    pdf_filename = "#{basename}#{ContentPresenter::PDF_EXT}"
    thumb_filename = "#{basename}#{ContentPresenter::THUMB_EXT}"

    pdf = ::DocumentExporter::Pdf::Material.new(material).export
    thumb = ::DocumentExporter::Thumbnail.new(pdf).export

    pdf_url = S3Service.upload pdf_filename, pdf
    thumb_url = S3Service.upload thumb_filename, thumb

    { "url" => pdf_url, "thumb" => thumb_url }
  end

  def material_presenter(material, document)
    DocumentGenerator.material_presenter.new material, lesson: DocumentGenerator.document_presenter.new(document)
  end
end

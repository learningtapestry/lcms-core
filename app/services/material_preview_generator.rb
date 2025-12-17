# frozen_string_literal: true

#
# Generates and uploads PDF/GDoc files for material
#
class MaterialPreviewGenerator
  GDOC_RE = %r{docs.google.com/document/d/([^/]*)}i
  PDF_S3_FOLDER = "temp-materials-pdf"

  attr_reader :error, :url

  def initialize(material, options = {})
    @material = material
    @options = options
  end

  def perform
    options[:type] == :pdf ? generate_pdf : generate_gdoc
  rescue StandardError => e
    @error = e.message
    false
  end

  private

  attr_reader :material, :options

  def generate_gdoc
    folder_id = options[:folder_id]
    file_id = material.preview_links["gdoc"].to_s.match(GDOC_RE)&.[](1)
    @url = DocumentExporter::Gdoc::Material.new(material).export_to(folder_id, file_id:).url
    true
  end

  def generate_pdf # rubocop:disable Naming/PredicateMethod
    pdf_filename = "#{PDF_S3_FOLDER}/#{material.base_filename}#{ContentPresenter::PDF_EXT}"
    pdf = DocumentExporter::Pdf::Material.new(material).export
    @url = S3Service.upload pdf_filename, pdf
    true
  end
end

# frozen_string_literal: true

class DocumentsController < Admin::AdminController
  include ErrorMessage

  skip_before_action :verify_authenticity_token, only: :show_lti
  skip_before_action :authenticate_user!, only: :show_lti

  before_action :set_document
  before_action :check_document_layout, only: :show

  skip_before_action :authenticate_admin!

  def preview_pdf
    link_keys = %w(preview pdf)

    if !ENV.fetch("FORCE_PREVIEW_GENERATION", false) && (url = @document.preview_links.dig(*link_keys)).present?
      return redirect_to url
    end

    job_options = {
      content_type: :preview,
      folder: ENV.fetch("AWS_S3_PREVIEW_FOLDER", "previews"),
      preview: true
    }
    DocumentPdfJob.perform_now(@document.id, job_options)

    redirect_to @document.reload.preview_links.dig(*link_keys, "url"), allow_other_host: true
  rescue StandardError => e
    redirect_to document_path(@document), alert: error_message_for(e)
  end

  def preview_gdoc
    link_keys = %w(preview gdoc)

    if !ENV.fetch("FORCE_PREVIEW_GENERATION", false) &&  (url = @document.preview_links.dig(*link_keys)).present?
      return redirect_to url
    end

    job_options = {
      content_type: :preview,
      folder_id: ENV.fetch("GOOGLE_APPLICATION_PREVIEW_FOLDER_ID"),
      preview: true
    }
    DocumentGdocJob.perform_now(@document.id, job_options)

    redirect_to @document.reload.preview_links.dig(*link_keys, "url"), allow_other_host: true
  rescue StandardError => e
    redirect_to document_path(@document), alert: error_message_for(e)
  end

  def show; end

  def show_lti
    # To allow access from iFrame element
    response.headers.delete "X-Frame-Options"

    render layout: "application_lti"
  end

  private

  attr_reader :type

  def check_document_layout
    return if @document.layout("default").present?

    redirect_to admin_documents_path, alert: "Document has to be re-imported."
  end

  def check_params
    head :bad_request unless params[:type].present? && params[:context].present?
  end

  def set_document
    entry = Document.find params[:id]
    @document = DocumentPresenter.new(entry, content_type: params[:type])
  end
end

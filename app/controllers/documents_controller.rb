# frozen_string_literal: true

class DocumentsController < Admin::AdminController
  skip_before_action :verify_authenticity_token, only: :show_lti
  skip_before_action :authenticate_user!, only: :show_lti

  before_action :set_document
  before_action :check_document_layout, only: :show

  skip_before_action :authenticate_admin!

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

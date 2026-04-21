# frozen_string_literal: true

module Admin
  class UnitsController < AdminController
    include GoogleCredentials
    include NestedReimportable
    include PdfGenerator
    include Queryable
    include Reimportable

    before_action :set_unit, only: %i(destroy unit_bundle_gdoc unit_bundle_pdf)
    before_action :find_selected, only: %i(destroy_selected reimport_selected)
    before_action :set_query_params # from Queryable

    QUERY_ATTRS = %i(
      grade
      search_term
      sort_by
      subject
    ).freeze
    QUERY_ATTRS_NESTED = {
      grades: []
    }.freeze
    QUERY_ATTRS_KEYS = QUERY_ATTRS + QUERY_ATTRS_NESTED.keys

    def index
      @query = query_struct(@query_params)
      @units = Admin::UnitsQuery.call(@query, page: params[:page])
      render_customized_view
    end

    def create
      @unit_form = UnitForm.new(form_params.except(:async))

      return create_multiple if form_params[:link].match?(RE_GOOGLE_FOLDER)

      form_params[:async].to_i.zero? ? create_sync : create_async
    end

    def destroy
      @unit = Resource.units.find(params[:id].to_i)
      @unit.destroy
      redirect_to admin_units_path(query: @query_params), notice: t(".success")
    end

    def destroy_selected
      count = @units.destroy_all.count
      redirect_to admin_units_path(query: @query_params), notice: t(".success", count:)
    end

    def import_status
      data = import_status_for(UnitParseJob)
      render json: data, status: :ok
    end

    def new
      @unit_form = UnitForm.new
    end

    def reimport_selected
      urls = []
      skipped = 0
      @units.each do |unit|
        if (url = unit.links.dig("source", "gdoc", "url")).present?
          urls << url
        else
          skipped += 1
        end
      end
      flash.now[:alert] = t(".skipped", count: skipped) if skipped.positive?
      bulk_import urls
      render :import
    end

    def unit_bundle_gdoc
      bulk_generation Array.wrap(@unit), :unit_bundle_gdoc
      render :bundle
    end

    def unit_bundle_gdoc_status
      data = import_status_for_nested PdfGenerator::REIMPORT_PARAMS.dig(:unit_bundle_gdoc, :job_class)
      render json: data, status: :ok
    end

    def unit_bundle_pdf
      bulk_generation Array.wrap(@unit), :unit_bundle_pdf
      render :bundle
    end

    def unit_bundle_pdf_status
      data = import_status_for_nested PdfGenerator::REIMPORT_PARAMS.dig(:unit_bundle_pdf, :job_class)
      render json: data, status: :ok
    end

    private

    def collect_errors
      @collect_errors ||=
        if @unit_form.service_errors.empty?
          []
        else
          @unit_form.service_errors.map { "<li>#{_1}</li>" }.join
        end
    end

    def create_async
      bulk_import Array.wrap(form_params[:link])
      render :import
    end

    def create_sync
      if @unit_form.save
        flash_message =
          if collect_errors.empty?
            { notice: t("admin.units.create.success", name: @unit_form.unit.title) }
          else
            { alert: t("admin.units.create.error", name: @unit_form.unit.title, errors: collect_errors) }
          end
        redirect_to admin_units_path(anchor: "unit_#{@unit_form.unit.id}", query: @query_params), **flash_message
      else
        render :new
      end
    end

    def bulk_import(file_urls)
      jobs =
        file_urls.each_with_object({}) do |url, jobs_|
          job_id = UnitParseJob.perform_later(url).job_id
          jobs_[job_id] = { link: url, status: "waiting" }
        end
      polling_path = import_status_admin_units_path
      @props =
        { jobs:, links: view_links, polling_path:, type: :units }
          .transform_keys! { _1.to_s.camelize(:lower).to_sym }
    end

    def find_selected
      return head(:bad_request) unless params[:selected_ids].present?

      ids = params[:selected_ids].split(",")
      @units = Resource.units.where(id: ids)
    end

    def form_params
      @form_params ||= params.require(:unit_form).permit(:async, :link)
    end

    def gdoc_files_from(url)
      folder_id = ::Lt::Google::Api::Drive.folder_id_for(url)
      ::Lt::Google::Api::Drive.new(google_credentials)
        .list_file_ids_in(folder_id)
        .map { |id| ::Lt::Lcms::Lesson::Downloader::Gdoc.gdoc_file_url(id) }
    end

    def set_unit
      @unit = UnitPresenter.new Resource.units.find(params[:id].to_i)
    end
  end
end

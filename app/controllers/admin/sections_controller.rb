# frozen_string_literal: true

module Admin
  class SectionsController < AdminController
    include GoogleCredentials
    include Reimportable
    include Queryable

    before_action :find_selected, only: %i(destroy_selected reimport_selected)
    before_action :set_query_params

    QUERY_ATTRS = %i(
      grade
      search_term
      section_number
      sort_by
      subject
      unit_id
    ).freeze
    QUERY_ATTRS_NESTED = {
      grades: []
    }.freeze
    QUERY_ATTRS_KEYS = QUERY_ATTRS + QUERY_ATTRS_NESTED.keys

    def index
      @query = query_struct(@query_params)
      @sections = Admin::SectionsQuery.call(@query, page: params[:page])
      render_customized_view
    end

    def create
      @section_form = SectionForm.new(form_params.except(:async).to_h)

      return create_multiple if form_params[:link].match?(RE_GOOGLE_FOLDER)

      form_params[:async].to_i.zero? ? create_sync : create_async
    end

    def destroy
      section = Resource.sections.find(params[:id].to_i)
      section.destroy
      redirect_to admin_sections_path(query: @query_params), notice: t(".success")
    end

    def destroy_selected
      count = @sections.destroy_all.count
      redirect_to admin_sections_path(query: @query_params), notice: t(".success", count:)
    end

    def import_status
      data = import_status_for(SectionParseJob)
      render json: data, status: :ok
    end

    def new
      @section_form = SectionForm.new
    end

    def reimport_selected
      urls = []
      skipped = 0
      @sections.each do |section|
        if (url = section.links.dig("source", "gdoc", "url")).present?
          urls << url
        else
          skipped += 1
        end
      end
      flash.now[:alert] = t(".skipped", count: skipped) if skipped.positive?
      bulk_import urls
      render :import
    end

    private

    def bulk_import(file_urls)
      jobs =
        file_urls.each_with_object({}) do |url, jobs_|
          job_id = SectionParseJob.perform_later(url).job_id
          jobs_[job_id] = { link: url, status: "waiting" }
        end
      polling_path = import_status_admin_sections_path
      @props = { jobs:, links: view_links, polling_path:, type: :sections }
                 .transform_keys! { _1.to_s.camelize(:lower).to_sym }
    end

    def collect_errors
      @collect_errors ||=
        if @section_form.service_errors.empty?
          []
        else
          @section_form.service_errors.map { "<li>#{_1}</li>" }.join
        end
    end

    def create_async
      bulk_import Array.wrap(form_params[:link])
      render :import
    end

    def create_sync
      if @section_form.save
        flash_message =
          if collect_errors.empty?
            { notice: t("admin.sections.create.success", name: @section_form.section.title) }
          else
            { alert: t("admin.sections.create.error", name: @section_form.section.title, errors: collect_errors) }
          end
        redirect_to admin_sections_path(anchor: "section_#{@section_form.section.id}", query: @query_params), **flash_message
      else
        render :new
      end
    end

    def find_selected
      return head(:bad_request) unless params[:selected_ids].present?

      ids = params[:selected_ids].split(",")
      @sections = Resource.sections.where(id: ids)
    end

    def form_params
      @form_params ||= params.require(:section_form).permit(:async, :link)
    end

    def gdoc_files_from(url)
      folder_id = ::Lt::Google::Api::Drive.folder_id_for(url)

      ::Lt::Google::Api::Drive.new(google_credentials)
        .list_file_ids_in(folder_id)
        .map { |id| ::Lt::Lcms::Lesson::Downloader::Gdoc.gdoc_file_url(id) }
    end
  end
end

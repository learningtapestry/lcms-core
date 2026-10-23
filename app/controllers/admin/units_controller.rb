# frozen_string_literal: true

module Admin
  class UnitsController < AdminController
    include GoogleCredentials
    include NestedReimportable
    include PdfGenerator
    include Queryable
    include Reimportable

    before_action :set_unit, only: %i(destroy digital_access edit full_download unit_bundle_gdoc unit_bundle_pdf update upload_cover)
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

    def edit; end

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

    def update
      cover_image_url = cover_params[:remove_cover_image] == "1" ? "" : cover_params[:cover_image_url].to_s.strip
      unless cover_image_url_allowed?(cover_image_url)
        flash.now[:alert] = t(".invalid_cover_image_url")
        return render :edit, status: :unprocessable_content
      end

      previous_url = @unit.metadata[UnitPresenter::COVER_IMAGE_KEY]
      @unit.update!(metadata: @unit.metadata.merge(
        UnitPresenter::COVER_IMAGE_KEY => cover_image_url.presence,
        UnitPresenter::COVER_CREDIT_KEY => cover_params[:cover_image_credit].to_s.strip.presence
      ).compact)
      UnitCoverUploader.delete_by_url(previous_url) if previous_url.present? && previous_url != cover_image_url

      redirect_to admin_units_path(anchor: "unit_#{@unit.id}", query: @query_params), notice: t(".success")
    end

    def upload_cover
      return head :unprocessable_entity unless params[:image].respond_to?(:tempfile)

      uploader = UnitCoverUploader.new
      uploader.store!(params[:image])
      render json: { url: uploader.url }
    rescue CarrierWave::IntegrityError, CarrierWave::ProcessingError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def unit_bundle_gdoc
      generate_bundle :unit_bundle_gdoc, "unit_bundle"
    end

    def unit_bundle_gdoc_status
      data = import_status_for_nested PdfGenerator::REIMPORT_PARAMS.dig(:unit_bundle_gdoc, :job_class)
      render json: data, status: :ok
    end

    def unit_bundle_pdf
      generate_bundle :unit_bundle_pdf, "unit_bundle"
    end

    def unit_bundle_pdf_status
      data = import_status_for_nested PdfGenerator::REIMPORT_PARAMS.dig(:unit_bundle_pdf, :job_class)
      render json: data, status: :ok
    end

    def digital_access
      generate_bundle :digital_access, "digital_access"
    end

    def digital_access_status
      data = import_status_for_nested PdfGenerator::REIMPORT_PARAMS.dig(:digital_access, :job_class)
      render json: data, status: :ok
    end

    def full_download
      generate_bundle :full_download, "full_download"
    end

    def full_download_status
      data = import_status_for_nested PdfGenerator::REIMPORT_PARAMS.dig(:full_download, :job_class)
      render json: data, status: :ok
    end

    private

    # Queues the unit's bundle job and shows its progress page, titled with
    # the bundle's name.
    def generate_bundle(generator_type, content_type)
      bulk_generation Array.wrap(@unit), generator_type
      @bundle_title = t("admin.bundle.#{content_type}")
      render :bundle
    end

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

    def cover_params
      params.fetch(:unit, {}).permit(:cover_image_credit, :cover_image_url, :remove_cover_image)
    end

    # The cover URL comes back from #upload_cover through a hidden form field,
    # so it is client-controlled. It is rendered into generated documents and
    # fetched server-side to inline it (AssetHelper.inline_data_uri), so only
    # accept what the uploader produces: a local path or a URL on the app's S3
    # bucket, under the uploader's store_dir. The unit's current cover is
    # always accepted (covers saved before they had their own directory).
    def cover_image_url_allowed?(url)
      url.blank? || url == @unit.metadata[UnitPresenter::COVER_IMAGE_KEY] || UnitCoverUploader.stored_url?(url)
    end

    def form_params
      @form_params ||= params.require(:unit_form).permit(:async, :link)
    end

    def set_unit
      @unit = UnitPresenter.new Resource.units.find(params[:id].to_i)
    end
  end
end

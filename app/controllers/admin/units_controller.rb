# frozen_string_literal: true

module Admin
  class UnitsController < AdminController
    include NestedReimportable
    include PdfGenerator
    include Queryable

    before_action :set_unit, only: %i(destroy unit_bundle_gdoc unit_bundle_pdf)
    before_action :find_selected, only: %i(destroy_selected)
    before_action :set_query_params # from Queryable

    QUERY_ATTRS = %i(
      grade
      module
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

    def destroy
      @unit = Resource.units.find(params[:id].to_i)
      @unit.destroy
      redirect_to admin_units_path(query: @query_params), notice: t(".success")
    end

    def destroy_selected
      count = @units.destroy_all.count
      redirect_to admin_units_path(query: @query_params), notice: t(".success", count:)
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

    def find_selected
      return head(:bad_request) unless params[:selected_ids].present?

      ids = params[:selected_ids].split(",")
      @units = Resource.units.where(id: ids)
    end

    def set_unit
      @unit = UnitPresenter.new Resource.units.find(params[:id].to_i)
    end
  end
end

# frozen_string_literal: true

module PdfGenerator # rubocop:disable Metrics/ModuleLength
  PREVIEW_LINKS = {
    # student_bundle: ["/units/:id/preview/student_bundle"],
    # teacher_bundle: ["/units/:id/preview/teacher_bundle"]
  }.freeze
  REIMPORT_PARAMS = {
    # student_bundle: {
    #   job_class: StudentBundlePdfJob,
    #   options: { with_dependants: true },
    #   props: {
    #     links: PREVIEW_LINKS[:student_bundle],
    #     polling_path: "/openscied/admin/units/student_bundle_status",
    #     with_pdf: true
    #   },
    #   query: Admin::UnitsQuery,
    #   query_extra_attrs: %i(subject)
    # },
    # teacher_bundle: {
    #   job_class: TeacherBundlePdfJob,
    #   options: { with_dependants: true },
    #   props: {
    #     links: PREVIEW_LINKS[:teacher_bundle],
    #     polling_path: "/openscied/admin/units/teacher_bundle_status",
    #     with_pdf: true
    #   },
    #   query: Admin::UnitsQuery,
    #   query_extra_attrs: %i(subject)
    # },
    unit_bundle_pdf: {
      job_class: UnitBundlePdfJob,
      options: { with_dependants: true },
      props: {
        links: [Rails.application.routes.url_helpers.root_path],
        polling_path: "/admin/units/unit_bundle_pdf_status"
      },
      query: Admin::UnitsQuery,
      query_extra_attrs: %i(subject)
    },
    unit_bundle_gdoc: {
      job_class: UnitBundleGdocJob,
      options: { with_dependants: true },
      props: {
        links: [Rails.application.routes.url_helpers.root_path],
        polling_path: "/admin/units/unit_bundle_gdoc_status"
      },
      query: Admin::UnitsQuery,
      query_extra_attrs: %i(subject)
    }
  }.freeze

  private

  def bulk_generation(entries, generator_type, opts = {})
    Resource.with_advisory_lock("pdf_generation_#{generator_type}") do
      generator_params = REIMPORT_PARAMS[generator_type]
      jobs = {}
      entries.each do |entry|
        # get already queued or running job for the entry or create a new one
        job_id = generator_params[:job_class].queued_or_running_job_for(entry.id, opts) ||
                 generator_params[:job_class].perform_later(entry.id, generator_params[:options].merge(opts)).job_id
        link = if generator_type == :teacher_bundle
                 teacher_bundle_unit_path(entry)
               elsif generator_type == :student_bundle
                 student_bundle_unit_path(entry)
               elsif %i(unit_bundle_pdf unit_bundle_gdoc).include?(generator_type)
                 root_path
               else
                 raise "Unknown generator type: #{generator_type}"
               end
        jobs[job_id] = { link: link, status: "waiting" }
      end
      @props = { jobs:, type: generator_type }
                 .merge(generator_params[:props])
                 .transform_keys { _1.to_s.camelize(:lower) }
    end
  end
end

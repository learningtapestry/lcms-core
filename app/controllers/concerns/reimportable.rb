# frozen_string_literal: true

module Reimportable
  private

  # Queues a parse of every record's source Google Doc and shows the import
  # status page, warning about records without a source (".skipped").
  #
  # @param [Enumerable<Resource>] records
  # @param [Class] presenter_class presenter including HasGdocSource
  def reimport_selected_from_source(records, presenter_class)
    urls = records.map { presenter_class.new(_1).source_url }
    skipped = urls.count(&:blank?)
    flash.now[:alert] = t(".skipped", count: skipped) if skipped.positive?
    bulk_import urls.compact_blank
    render :import
  end

  # Queues a parse of +resource+'s source Google Doc (via the controller's
  # #bulk_import) and shows the import status page, or goes back to
  # +fallback_path+ when the resource has no source document.
  #
  # @param [HasGdocSource] resource presenter exposing #source_url
  # @param [String] fallback_path
  def reimport_from_source(resource, fallback_path)
    if resource.source_url.blank?
      return redirect_to fallback_path, alert: t("admin.shared.reimport.no_source")
    end

    bulk_import [resource.source_url]
    render :import
  end

  def create_multiple
    # Import all from a folder
    file_ids = gdoc_files_from form_params[:link]
    return bulk_import(file_ids) && render(:import) if file_ids.any?

    flash.now[:alert] = t "admin.common.empty_folder"
    render(:new)
  end

  #
  # @param [String] url
  # @return [Array<String>]
  #
  def gdoc_files_from(url)
    folder_id = ::Lt::Google::Api::Drive.folder_id_for(url)
    ::Lt::Google::Api::Drive.new(google_credentials)
      .list_file_ids_in(folder_id)
      .map { |id| ::Lt::Lcms::Lesson::Downloader::Gdoc.gdoc_file_url(id) }
  end

  def import_status_for(job_class)
    jids = params.fetch(:jids, [])
    return {} if jids.empty?

    statuses = job_class.status_batch(jids)
    done_jids = statuses.select { |_, s| s == :done }.keys
    results = job_class.fetch_results_batch(done_jids)

    jids.each_with_object({}) do |jid, obj|
      status = statuses[jid]
      obj[jid] = {
        status:,
        result: (status == :done ? prepare_result(results[jid], jid) : nil)
      }.compact
    end
  end

  def prepare_result(jid_res, jid)
    return jid_res if jid_res&.[]("ok")

    error =
      if jid_res.present?
        "<a href=\"#{jid_res['link']}\">Source</a>: #{jid_res['errors'].join(', ')}"
      else
        "Error fetching result for #{jid}"
      end

    {
      ok: false,
      errors: Array.wrap(error)
    }
  end
end

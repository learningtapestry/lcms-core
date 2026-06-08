# frozen_string_literal: true

module Reimportable
  private

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

# frozen_string_literal: true

#
# For the bundle jobs that gather files into folders (Teacher Bundle for
# Digital Access, Full Unit Content for Download): picking up the PDFs nested
# DocumentPdfJob / MaterialPdfJob runs rendered under the bundle's content
# type, and noting the Non-LCMS files left out of the bundle.
#
module BundleFiles
  extend ActiveSupport::Concern

  private

  # Notes when the PDFs were queued (carried to the requeued run in its
  # options), so #stored_pdf can tell a PDF from this run from one a failed
  # nested job left behind from an earlier run.
  def note_pdfs_queued
    options[:dependants_queued_at] = Time.current.to_i
  end

  # The PDF the nested job stored for this lesson or material during this run;
  # nil when there is none, or only an older one (the job failed this time).
  def stored_pdf(record)
    entry = record.reload.links.dig(self.class::CONTENT_TYPE.to_s, "pdf") || {}
    queued_at = options[:dependants_queued_at]
    return if entry["url"].blank? || (queued_at && entry["timestamp"].to_i < queued_at)

    S3Service.read_data_from_s3(URI.parse(entry["url"]))
  end

  def pdf_job_options
    { content_type: self.class::CONTENT_TYPE.to_s, initial_job_id: }.merge(options.slice(*UnitBundlePdfJob::PDF_OPTION_KEYS))
  end

  # Shown on the bundle status page: the Non-LCMS files left out of the
  # bundle (see #skip_file).
  def bundle_warnings
    return [] if skipped_files.empty?

    lines = skipped_files.map { ERB::Util.html_escape("#{it[:folder]}/#{it[:file]}: #{it[:reason]}") }
    [I18n.t("bundles.skipped.title", count: skipped_files.size), *lines]
  end

  def skipped_files
    @skipped_files ||= []
  end

  def skip_file(folder, file, reason)
    Rails.logger.warn("#{self.class.name}: skipped #{folder}/#{file}: #{reason}")
    skipped_files << { folder:, file:, reason: }
  end
end

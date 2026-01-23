# frozen_string_literal: true

#
# Job to generate Google Docs bundle for a unit including all dependent lesson Google Docs
#
class UnitBundleGdocJob < BaseBundleJob
  include UnitLevelJob

  CONTENT_TYPE = :tm
  NESTED_JOBS = %w(DocumentGenerateGdocJob UnitBundleGdocJob).freeze

  queue_as :default

  def perform(entry_id, options = {})
    perform_generation_for(entry_id, options.merge(ignore_result: true, raise_errors: true))
  rescue StandardError => e
    additional_info = {
      job_options: options,
      unit_id: entry_id
    }
    ::Airbrake.notify_sync(e, additional_info) if defined?(Airbrake)
    errors = [e.message]
    errors.concat(e.backtrace.select { |l| l.include?("lcms") })
    store_initial_result({ ok: false, errors: errors }, options)
  end

  private

  #
  # Doesn't generate anything specific but the dependent GDocs
  #
  def generate_bundle
    # Store bundle generation data in unit links
    unit.reload.with_lock do
      data = { timestamp: Time.current.to_i, status: "completed" }
      links = unit.links.deep_merge("gdoc_bundle" => { CONTENT_TYPE.to_s => data })
      unit.update links: links
    end

    results = { ok: true, link: "completed", model: unit }
    store_initial_result(results, options)
  end

  def generate_dependants
    # Generate Google Docs for each lesson in the unit
    unit.lessons.each do |lesson|
      # Skip if lesson already has a Google Doc generated
      next if lesson.links.dig("gdoc", "url").present?

      DocumentGenerateGdocJob.set(queue: :default).perform_later(
        lesson,
        initial_job_id: initial_job_id
      )
    end
  end
end

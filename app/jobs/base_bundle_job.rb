# frozen_string_literal: true

#
# Base class to generate bundles that depends on generation of other resources first
# Shouldn't be called itself, constants should be defined in inherited classes
#
class BaseBundleJob < ApplicationJob
  include ResqueJob
  include NestedResqueJob

  def perform(_entry_id, _options = {})
    raise NotImplementedError
  end

  private

  attr_reader :options, :unit

  def generate_bundle
    raise NotImplementedError
  end

  def generate_dependants
    raise NotImplementedError
  end

  def perform_generation_for(entry_id, options = {})
    options = { ignore_result: false, raise_errors: false }.merge(options)
    entry = Resource.find(entry_id)
    @unit = UnitPresenter.new(entry)
    @options = options.merge(content_type: self.class::CONTENT_TYPE.to_s)

    # requeue if we already have this kind of bundle job for this unit
    requeue(with_dependants: true) && return if with_dependants? && queued?

    generate_dependants if with_dependants?

    # If there are running dependants triggered by the previous line,
    # we queue the job itself to be run after all dependants will be generated
    requeue && return if self.class.queued_or_running_nested?(initial_job_id, job_id)

    url = generate_bundle

    store_initial_result({ ok: true, link: url, model: entry }, options) unless options[:ignore_result]
  rescue StandardError => e
    raise if options[:raise_errors]

    store_initial_result({ ok: false, errors: [e.message] }, options)
    if defined?(Airbrake)
      additional_info = {
        job_options: options,
        unit_id: entry_id
      }
      ::Airbrake.notify_sync(e, additional_info)
    end
  end

  def requeue(with_dependants: false)
    self.class.perform_later(
      unit.id,
      options.merge(initial_job_id: initial_job_id, with_dependants: with_dependants)
    )
  end

  def with_dependants?
    options[:with_dependants].present?
  end
end

# frozen_string_literal: true

module MaterialRescuableJob
  extend ActiveSupport::Concern
  include Rails.application.routes.url_helpers

  included do
    # remove correspondent links on errors
    rescue_from(StandardError) do |e|
      material_id = Material.find(arguments[0])
      material = MaterialPresenter.new(material_id)
      options = (arguments[1] || {}).with_indifferent_access
      unless options[:preview]
        material.reload.with_lock do
          material.update_columns(links: material.links.merge(self.class::LINK_KEY => {}))
        end
        store_result({ ok: false,
                       link: material_path(material),
                       errors: [material.identifier, e.message] }, options)
      end
      if defined?(Airbrake)
        additional_info = {
          job_options: options,
          material_id:
        }
        ::Airbrake.notify_sync(e, additional_info)
      end
      raise e
    end
  end
end

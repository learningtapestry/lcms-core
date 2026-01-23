# frozen_string_literal: true

module DocumentRescuableJob
  extend ActiveSupport::Concern
  include Rails.application.routes.url_helpers

  included do
    # remove correspondent links on errors
    rescue_from(StandardError) do |e|
      document_id = arguments[0]
      options = (arguments[1] || {}).with_indifferent_access
      unless options[:preview]
        document = Document.find(document_id)
        document.reload.with_lock do
          data = document.links[self.class::LINK_KEY]&.slice("preview") || {}
          document.update_columns(links: document.reload.links.merge(self.class::LINK_KEY => data))
        end
        store_result({ ok: false,
                       link: document_path(document_id),
                       errors: [document.name, e.message] }, options)
      end
      if defined?(Airbrake)
        additional_info = {
          job_options: options,
          document_id:
        }
        ::Airbrake.notify_sync(e, additional_info)
      end
      raise e
    end
  end
end

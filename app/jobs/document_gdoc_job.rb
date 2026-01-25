# frozen_string_literal: true

class DocumentGdocJob < ApplicationJob
  include DocumentRescuableJob
  include ResqueJob

  queue_as :default

  LINK_KEY = "gdoc"

  def perform(entry_id, options)
    options = options.with_indifferent_access
    content_type = options[:content_type].to_sym
    entry = Document.find(entry_id)
    document = DocumentPresenter.new(entry, content_type:)
    gdoc = Exporters::Gdoc::Document.new(document, options).export

    data = {
      content_type.to_s => {
        LINK_KEY => {
          url: gdoc.url,
          timestamp: Time.current.to_i,
          pages: -1
        }
      }
    }

    document.with_lock do
      if options[:preview]
        document.update preview_links: document.reload.preview_links.deep_merge(data)
      else
        document.update links: document.reload.links.deep_merge(data)
      end
    end
  end
end

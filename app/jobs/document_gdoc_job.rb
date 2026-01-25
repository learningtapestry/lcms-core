# frozen_string_literal: true

#
# Job to generate a Google Doc for a single document.
#
# This job creates a Google Doc version of a document and stores the link
# in either the `links` or `preview_links` field depending on the options.
#
# @example Basic usage
#   DocumentGdocJob.perform_later(document.id, content_type: :unit_bundle)
#
# @example Preview mode
#   DocumentGdocJob.perform_later(document.id, content_type: :preview, preview: true)
#
# @see Exporters::Gdoc::Document
# @see Google::ScriptService
#
class DocumentGdocJob < ApplicationJob
  include DocumentRescuableJob
  include ResqueJob

  queue_as :default

  LINK_KEY = "gdoc"

  # Generates a Google Doc for the specified document.
  #
  # @param entry_id [Integer] the ID of the Document record
  # @param options [Hash] generation options
  # @option options [String, Symbol] :content_type the content type for rendering
  # @option options [String] :folder_id optional Google Drive folder ID
  # @option options [Boolean] :preview if true, stores result in preview_links instead of links
  # @return [void]
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

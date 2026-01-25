# frozen_string_literal: true

#
# Job to generate a Google Doc for a single material.
#
# This job creates a Google Doc version of a material and stores the link
# in either the `links` or `preview_links` field depending on the options.
#
# @example Basic usage
#   MaterialGdocJob.perform_later(material.id, content_type: :unit_bundle)
#
# @example With folder specification
#   MaterialGdocJob.perform_later(material.id, content_type: :unit_bundle, folder_id: "abc123")
#
# @example Preview mode
#   MaterialGdocJob.perform_later(material.id, content_type: :preview, preview: true)
#
# @see Exporters::Gdoc::Material
# @see Google::ScriptService
#
class MaterialGdocJob < ApplicationJob
  include MaterialRescuableJob
  include ResqueJob

  queue_as :default

  LINK_KEY = "gdoc"

  # Generates a Google Doc for the specified material.
  #
  # @param entry_id [Integer] the ID of the Material record
  # @param options [Hash] generation options
  # @option options [String, Symbol] :content_type the content type for rendering
  # @option options [String] :folder_id Google Drive folder ID where the file will be stored
  # @option options [Boolean] :preview if true, stores result in preview_links instead of links
  # @return [void]
  def perform(entry_id, options)
    options = options.with_indifferent_access
    content_type = options[:content_type].to_sym
    entry = Material.find(entry_id)
    material = MaterialPresenter.new(entry, content_type:)
    gdoc = Exporters::Gdoc::Material.new(material, options).export

    data = {
      content_type.to_s => {
        LINK_KEY => {
          url: gdoc.url,
          timestamp: Time.current.to_i,
          pages: -1
        }
      }
    }

    material.with_lock do
      if options[:preview]
        material.update preview_links: material.reload.preview_links.deep_merge(data)
      else
        material.update links: material.reload.links.deep_merge(data)
      end
    end
  end
end

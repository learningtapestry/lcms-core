# frozen_string_literal: true

class MaterialGdocJob < ApplicationJob
  include MaterialRescuableJob
  include ResqueJob

  queue_as :default

  LINK_KEY = "gdoc"

  #
  # Options values:
  #  - folder_id: Where generated file will be stored
  #  - preview: true or false
  #
  # @param [Integer] entry_id
  # @param [Hash] options
  #
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

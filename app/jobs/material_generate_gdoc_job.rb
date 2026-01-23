# frozen_string_literal: true

class MaterialGenerateGdocJob < ApplicationJob
  include ResqueJob
  include RetryDelayed

  queue_as :default

  def perform(material, document)
    material = MaterialPresenter.new(
      material,
      document: DocumentPresenter.new(document)
    )

    # Check if material is optional for current document
    options = {}.tap do |x|
      x[:prefix] = "optional-" if material.optional_for?(document)
    end

    gdoc = Exporters::Gdoc::Material.new(material, options).export

    new_links = {
      "materials" => {
        material.id.to_s => { "gdoc" => gdoc.url }
      }
    }

    document.with_lock do
      links = document.reload.links
      document.update links: links.deep_merge(new_links)
    end
  end
end

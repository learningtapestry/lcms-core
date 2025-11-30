# frozen_string_literal: true

class MaterialGenerateJob < ApplicationJob
  include ResqueJob

  queue_as :default

  def perform(material, document)
    if document.math?
      material.document_parts.default.each { |p| p.update!(content: EmbedEquations.call(p.content)) }
    end

    DocumentGenerator.material_generators.each do |klass|
      klass.constantize.perform_later material, document
    end
  end
end

# frozen_string_literal: true

class UnitPresenter < BasePresenter
  def acknowledgements
    metadata["acknowledgements"]
  end

  def bundle_folder(bundle_type = nil)
    folder = "#{BUNDLE_S3_FOLDER}"
    folder += "/#{bundle_type}" if bundle_type.present?
    "#{folder}/#{s3_folder}"
  end

  def course
    metadata["course"]
  end

  def copyright
    metadata["copyright"]
  end

  def description
    metadata["description"]
  end

  def license
    metadata["license"]
  end

  def lessons
    @lessons ||= descendants.lessons.with_documents.map { DocumentPresenter.new(it.document) }
  end

  def materials
    unit_bundle_interactor.materials
  end

  def source_url
    links.dig("source", "gdoc", "url")
  end

  def unit_id
    metadata["unit_id"]
  end

  def unit_title
    metadata["unit_title"].presence || title
  end

  def unit_title_spanish
    metadata["unit_title_spanish"]
  end

  def unit_topic
    metadata["unit_topic"]
  end

  def unit_topic_spanish
    metadata["unit_topic_spanish"]
  end

  def s3_folder
    Breadcrumbs.new(self).short_pieces.join("_")
  end

  private

  # TODO: why we use interactor? shouldn't it be a Query?
  def unit_bundle_interactor
    @unit_bundle_interactor ||= UnitBundleInteractor.call(self)
  end
end

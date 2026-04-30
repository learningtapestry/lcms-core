# frozen_string_literal: true

class UnitPresenter < BasePresenter
  delegate :acknowledgements, :copyright, :course, :description, :license,
           :unit_id, :unit_title_spanish, :unit_topic, :unit_topic_spanish,
           to: :base_metadata

  def bundle_folder(bundle_type = nil)
    folder = "#{BUNDLE_S3_FOLDER}"
    folder += "/#{bundle_type}" if bundle_type.present?
    "#{folder}/#{s3_folder}"
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

  def unit_title
    base_metadata.unit_title.presence || title
  end

  def s3_folder
    Breadcrumbs.new(self).short_pieces.join("_")
  end

  private

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Unit.build_from(metadata)
  end

  # TODO: why we use interactor? shouldn't it be a Query?
  def unit_bundle_interactor
    @unit_bundle_interactor ||= UnitBundleInteractor.call(self)
  end
end

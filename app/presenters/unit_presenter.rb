# frozen_string_literal: true

class UnitPresenter < BasePresenter
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

  private

  def s3_folder
    Breadcrumbs.new(self).short_pieces.join("_")
  end

  def unit_bundle_interactor
    @unit_bundle_interactor ||= UnitBundleInteractor.call(self)
  end
end

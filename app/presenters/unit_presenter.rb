# frozen_string_literal: true

class UnitPresenter < BasePresenter
  def lessons
    @lessons ||= descendants.lessons.with_documents.map { DocumentPresenter.new(it.document) }
  end
end

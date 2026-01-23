# frozen_string_literal: true

class UnitBundleInteractor < BaseInteractor
  attr_reader :materials, :unit
  def run
    @unit = context
    @materials = collect_materials
  end

  private

  def collect_materials
    Material.where_metadata(
      subject: unit.metadata["subject"],
      grade: unit.metadata["grade"],
      module: unit.metadata["module"],
      unit: unit.metadata["unit"]
    ).map { MaterialPresenter.new(it) }
  end
end

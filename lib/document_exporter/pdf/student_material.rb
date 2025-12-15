# frozen_string_literal: true

module DocumentExporter
  module Pdf
    class StudentMaterial < Pdf::Base
      def export
        pdf = CombinePDF.new

        scope = @document.student_materials.where(id: included_materials)
        # TODO: Implement
        material_ids = []
        pdf = combine_pdf_for pdf, material_ids
        pdf.to_pdf
      end
    end
  end
end

# frozen_string_literal: true

module DocumentExporter
  module Pdf
    class TeacherMaterial < Pdf::Base
      def export
        content = super
        pdf = CombinePDF.parse(content)

        scope = @document.teacher_materials.where(id: included_materials)
        # TODO: Implement
        material_ids = []
        pdf = combine_pdf_for pdf, material_ids
        pdf.to_pdf
      end
    end
  end
end

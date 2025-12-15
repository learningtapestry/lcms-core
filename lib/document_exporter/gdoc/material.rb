# frozen_string_literal: true

module DocumentExporter
  module Gdoc
    class Material < Gdoc::Base
      def export
        @options[:subfolders] = [ DocumentExporter::Gdoc::StudentMaterial::FOLDER_NAME ] if document.student_material?
        @options[:subfolders] = [ DocumentExporter::Gdoc::TeacherMaterial::FOLDER_NAME ] if document.teacher_material?
        unless @options.key?(:subfolders)
          Rails.logger.warn "Material belongs neither to teachers nor to students: #{document.id}"
          @options[:subfolders] = [ "Materials" ]
        end

        super
      end

      private

      def template_path(name)
        File.join("documents", "gdoc", "materials", name)
      end
    end
  end
end

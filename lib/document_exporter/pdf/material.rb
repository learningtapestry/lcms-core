# frozen_string_literal: true

module DocumentExporter
  module Pdf
    class Material < Pdf::Base
      private

      def template_path(name)
        custom_template_for(name).presence || File.join("documents", "pdf", "materials", name)
      end
    end
  end
end

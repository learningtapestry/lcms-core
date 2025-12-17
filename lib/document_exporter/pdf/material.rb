# frozen_string_literal: true

module DocumentExporter
  module Pdf
    class Material < Pdf::Base
      private

      def base_path(name)
        File.join("materials", "pdf", name)
      end
    end
  end
end

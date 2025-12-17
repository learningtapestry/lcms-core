# frozen_string_literal: true

module DocumentExporter
  module Pdf
    class Document < Pdf::Base
      private

      def base_path(name)
        File.join("documents", "pdf", name)
      end
    end
  end
end

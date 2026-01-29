# frozen_string_literal: true

module Exporters
  module Gdoc
    class Document < Gdoc::Base
      private

      def base_path(name)
        File.join("documents", "gdoc", name)
      end
    end
  end
end

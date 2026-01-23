# frozen_string_literal: true

module Exporters
  module Gdoc
    class Material < Gdoc::Base
      private

      def template_path(name)
        # TODO: Change to "materials" folder
        File.join("documents", "gdoc", "materials", name)
      end
    end
  end
end

# frozen_string_literal: true

module Exporters
  module Gdoc
    class Material < Gdoc::Base
      private

      def template_path(name)
        File.join("materials", "gdoc", name)
      end
    end
  end
end

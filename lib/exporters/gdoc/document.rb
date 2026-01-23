# frozen_string_literal: true

module Exporters
  module Gdoc
    class Document < Gdoc::Base
      def export
        super
        gdoc_folder
      end
    end
  end
end

# frozen_string_literal: true

module Exporters
  module Gdoc
    #
    # Unit document Google Doc (the Teacher Edition front matter, starting with
    # the cover). Expects a UnitPresenter.
    #
    class Unit < Gdoc::Base
      private

      def template_path(name)
        File.join("units", "gdoc", name)
      end
    end
  end
end

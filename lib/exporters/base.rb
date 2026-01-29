# frozen_string_literal: true

module Exporters
  class Base
    def initialize(document, options = {})
      @document = document
      @options = options
    end

    def export
      raise NotImplementedError
    end

    private

    def base_path(name)
      raise NotImplementedError
    end

    def render_template(path, layout:)
      field = path.starts_with?("/") ? :file : :template
      ApplicationController.render(
        field => path,
        layout:,
        assigns: { document: @document, options: @options }
      )
    end

    def template_path(name)
      base_path(name)
    end
  end
end

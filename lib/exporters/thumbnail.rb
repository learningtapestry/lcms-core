# frozen_string_literal: true

module Exporters
  class Thumbnail
    THUMBNAIL_RATIO = 1.25

    def initialize(content)
      @content = content
    end

    def export
      pdf = ::MiniMagick::Image.read(@content)
      width = pdf.pages[0].width / THUMBNAIL_RATIO
      height = pdf.pages[0].height / THUMBNAIL_RATIO

      pdf.format("jpg", 0)
      pdf.combine_options do |c|
        c.density(300)
        c.background("#fff")
        c.alpha("remove")
        c.resize("#{width}x#{height}")
      end

      pdf.to_blob
    end
  end
end

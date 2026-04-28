# frozen_string_literal: true

class SectionPresenter < BasePresenter
  def section_number
    metadata["section_number"].presence || metadata["section"]
  end

  def section_title
    metadata["section_title"].presence || title
  end

  def section_title_spanish
    metadata["section_title_spanish"]
  end

  def source_url
    links.dig("source", "gdoc", "url")
  end

  def unit_id
    metadata["unit_id"].presence || metadata["unit"]
  end
end

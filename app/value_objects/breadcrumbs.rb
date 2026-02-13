# frozen_string_literal: true

class Breadcrumbs
  NUMERIC_PATTERN = /^\d+$/

  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  def full_title
    Resource.hierarchy.map do |key|
      val = resource.metadata[key.to_s]
      key == :subject ? val&.upcase : val&.humanize
    end.compact.join(" / ")
  end

  def pieces
    Resource.hierarchy.map do |key|
      if resource.curriculum_type&.to_sym == key
        resource.metadata[key.to_s]
      else
        send(:"#{key}_abbrv")
      end
    end.compact
  end

  def short_pieces
    # Calls
    #  - subject_abbrv
    #  - grade_abbrv
    #  - unit_abbrv
    #  - section_abbrv
    #  - lesson_abbrv
    #
    Resource.hierarchy.map { |key| send(:"#{key}_abbrv", short: true) }.compact
  end

  def short_title
    short_pieces.join(" / ")
  end

  def title
    pieces.join(" / ")
  end

  private

  def grade_abbrv(*)
    case grade = resource.metadata["grade"]
    when "prekindergarten" then "PK"
    when "kindergarten" then "K"
    else "G#{grade}"
    end
  end

  def unit_abbrv(*)
    unit = resource.metadata["unit"].to_s
    return if unit.blank?

    # Extract number from "unit N" format
    number = unit.match(/(\d+)/i)&.captures&.first
    number ? "U#{number}" : unit
  end

  def section_abbrv(*)
    section = resource.metadata["section"].to_s
    return if section.blank?

    # Extract number from "section N" format
    number = section.match(/(\d+)/)&.captures&.first
    number ? "S#{number}" : section
  end

  def lesson_abbrv(*)
    lesson = resource.metadata["lesson"].to_s
    return if lesson.blank?

    # Extract number from "lesson N" format
    number = lesson.match(/(\d+)/)&.captures&.first
    number ? "L#{number}" : lesson
  end

  def subject_abbrv(short: false)
    value = resource.metadata["subject"].to_s.to_sym
    if short
      SUBJECTS_SHORT[value]
    else
      SUBJECTS[value]
    end
  end
end

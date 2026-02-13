# frozen_string_literal: true

class HierarchicalPosition
  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  # Position mask:
  # - We use 6 blocks of 2 numbers for:
  #     subject, grade, unit, section, lesson, grade_present
  def position
    grade = resource.metadata["grade"]
    [
      subject_position, # subject
      GRADES.index(grade), # grade
      unit_position, # unit
      section_position, # section
      lesson_position, # lesson
      grade.present? ? 1 : 0 # grade present
    ].map { |v| v.to_s.rjust(2, "0") }.join(" ")
  end

  private

  def default_position
    @default_position ||= Array.new(7, "99").join(" ")
  end

  def subject_position
    val = SUBJECTS.keys.index(resource.subject)
    val ? val + 1 : 99
  end

  def unit_position
    position_for :unit?
  end

  def section_position
    position_for :section?
  end

  def position_for(type)
    val = if !resource.persisted? && resource.send(type)
            resource.level_position
          else
            resource.self_and_ancestors_not_persisted.detect { |res| res.send type }&.level_position
          end
    val ? val + 1 : 0
  end

  def lesson_position
    val =  resource.lesson? ? resource.level_position : nil
    return val if val

    resource.metadata["lesson"].to_s.match(/(\d+)/)&.captures&.first.to_i
  end
end

# frozen_string_literal: true

class HierarchicalPosition
  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  # Position mask:
  # - We use 7 blocks of 2 numbers for:
  #     subject, grades (average if more than one), module, unit,
  #     lesson, num_of_grades
  # - The last position is the number of different grades covered, i.e:
  #   a resource with 3 different grades show after one with 2, (more specific
  #   at the top, more generic at the bottom)
  def position
    [
      subject_position, # subject
      resource.grades.average_number, # grades
      module_position, # module
      unit_position, # unit
      lesson_position, # lesson
      resource.grades.list.size # number of grades
    ].map { |v| v.to_s.rjust(2, "0") }.join(" ")
  end

  private

  def default_position
    @default_position ||= Array.new(7, "99").join(" ")
  end

  def subject_position
    val = SUBJECTS.index(resource.subject)
    val ? val + 1 : 99
  end

  def module_position
    position_for :module?
  end

  def unit_position
    position_for :unit?
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

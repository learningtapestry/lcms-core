# frozen_string_literal: true

module DigitalAccess
  #
  # The folder tree of a unit's Teacher Bundle for Digital Access:
  #
  #   <Digital Access Root>/<course>/<unit>/<section>/<lesson>
  #
  # Each unit, section and lesson folder takes the name of the matching
  # folder in the client's Non-LCMS Root Folder, which mirrors the same tree
  # (Unit folders at its top, Section folders inside them, Lesson folders
  # inside those). A folder matches when its name carries the level and
  # number, e.g. "Unit 1: Plants", "Section 2 - Seeds", "Lesson 03 Roots"; a
  # unit folder may carry the unit id instead. Without a match the folder is
  # named from our metadata ("Lesson 3: <lesson title>").
  #
  # #build creates the output folders (or finds them, so a rebuild updates the
  # same tree) and returns their ids next to the matching Non-LCMS folders.
  # Without an output root it only names the folders (folder_id stays nil):
  # the Full Unit Content for Download lays out its zip from the same tree.
  #
  class Layout
    Node = Struct.new(:record, :name, :folder_id, :source_id, :children, keyword_init: true)

    # @param unit [UnitPresenter]
    # @param drive [DigitalAccess::Drive]
    # @param output_root_id [String, nil] the Digital Access Root Folder; nil
    #   to name the folders without creating them
    # @param source_root_id [String, nil] the Non-LCMS Root Folder
    def initialize(unit, drive:, output_root_id:, source_root_id: nil)
      @unit = unit
      @drive = drive
      @output_root_id = output_root_id
      @source_root_id = source_root_id
    end

    # @return [Node] the course folder: its child is the unit folder, whose
    #   children are the section folders, whose children are the lessons.
    def build
      course_id = create_folder(course_name, @output_root_id)
      unit_node = node(@unit, unit_name, course_id, unit_source_id)
      unit_node.children = @unit.sections.map do |section|
        section_source = source_folder(unit_node.source_id) { numbered?(it, "section", section.section_number) }
        section_node = node(section, section_source&.name || default_name("section", section.section_number, section.section_title),
                            unit_node.folder_id, section_source&.id)
        section_node.children = section.lessons.map do |lesson|
          lesson_source = source_folder(section_node.source_id) { numbered?(it, "lesson", lesson.lesson_number) }
          node(lesson, lesson_source&.name || default_name("lesson", lesson.lesson_number, lesson.lesson_title),
               section_node.folder_id, lesson_source&.id)
        end
        section_node
      end
      Node.new(record: nil, name: course_name, folder_id: course_id, source_id: @source_root_id, children: [unit_node])
    end

    # "Unit 3" is numbered as 3, "lesson 03 - Roots" as 3, "Lesson 3a" as 3a.
    def self.numbered?(name, level, number)
      return false if number.blank?

      token = name.to_s[/\b#{level}\s*[-_#:.]?\s*0*([[:alnum:]]+)/i, 1]
      token.present? && token.casecmp?(number.to_s.strip.sub(/\A0+(?=.)/, ""))
    end

    private

    def node(record, name, parent_id, source_id)
      Node.new(record:, name:, folder_id: create_folder(name, parent_id), source_id:, children: [])
    end

    def create_folder(name, parent_id)
      @drive.folder(name, parent_id) if parent_id
    end

    def course_name
      @unit.course.presence || I18n.t("digital_access.course")
    end

    def unit_source_id
      unit_source&.id
    end

    def unit_name
      unit_source&.name || [unit_label, @unit.unit_title].compact_blank.join(": ")
    end

    def unit_source
      return @unit_source if defined?(@unit_source)

      @unit_source = source_folder(@source_root_id) do |name|
        numbered?(name, "unit", @unit.unit_number) ||
          (@unit.unit_id.present? && name.match?(/(?<![[:alnum:]])#{Regexp.escape(@unit.unit_id)}(?![[:alnum:]])/i))
      end
    end

    def unit_label
      number = @unit.unit_number
      number ? "#{I18n.t('digital_access.unit')} #{number}" : @unit.unit_id.presence
    end

    def default_name(level, number, title)
      label = ("#{I18n.t("digital_access.#{level}")} #{number}" if number.present?)
      [label, title].compact_blank.join(": ").presence || I18n.t("digital_access.#{level}")
    end

    def numbered?(name, level, number)
      self.class.numbered?(name, level, number)
    end

    # The first sub-folder of `parent_id` whose name satisfies the block.
    def source_folder(parent_id, &)
      return if parent_id.nil?

      (@source_children ||= {})[parent_id] ||= @drive.children(parent_id).select(&:folder)
      @source_children[parent_id].find { yield it.name }
    end
  end
end

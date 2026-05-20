# frozen_string_literal: true

#
# Handles Document metadata contexts, to find and/or create corresponding Resources
#
module Lt
  module Lcms
    module Metadata
      class Context
        attr_reader :context

        RE_NUM = /\d+/
        RE_NUMBER = /^\d+$/
        private_constant :RE_NUMBER

        class << self
          #
          # Fix level position for grades
          # Is used inside `#find_or_create_resource` method
          #
          def update_grades_level_position_for(grades)
            update_level_position_for(grades) { |g| GRADES.index(g.metadata["grade"]) }
          end

          #
          # Fix level position for units
          # Is used inside `#find_or_create_resource` method
          #
          def update_units_level_position_for(units)
            indexes = units.map(&:short_title).sort_by { |g| g.to_s[RE_NUM].to_i }
            update_level_position_for(units) { |m| indexes.index(m.metadata["unit"]) }
          end

          #
          # Fix level position for sections
          # Is used inside `#find_or_create_resource` method
          #
          def update_sections_level_position_for(sections)
            update_level_position_for(sections) { |u| u.metadata["section"][RE_NUM].to_i }
          end

          #
          # Fix level position for in case when lower curriculum elements have
          # been created after higher ones: Grade 8 was created before Grade 7
          #
          def update_level_position_for(resources)
            resources
              .map { |m| { id: m.id, idx: yield(m) } }
              .sort_by { |a| a[:idx] }.each_with_index do |data, idx|
                resource = ::Resource.find(data[:id])
                resource.update_columns(level_position: idx) unless resource.level_position == idx
              end
          end
        end

        def initialize(context = {})
          @context = context.with_indifferent_access
        end

        def directory
          @directory ||= [subject, grade, unit, section, lesson].select(&:present?)
        end

        def metadata
          @metadata ||= {
            "subject" => subject,
            "grade" => grade,
            "unit" => unit,
            "section" => section,
            "lesson" => lesson
          }.compact.stringify_keys
        end

        #
        # @return [Resource]
        #
        def find_or_create_resource
          Resource.with_advisory_lock("find_or_create_resource") do
            # if the resource exists, return it
            # TODO: Remove debug
            # raise directory.inspect
            resource = Resource.tree.find_by_directory(directory)
            return update(resource) if resource

            # else, build missing parents until we build the resource itself.
            parent = nil
            directory.each_with_index do |name, index|
              resource = Resource.tree.find_by_directory(directory[0..index])
              if resource
                parent = resource
                next
              end

              resource = build_new_resource(parent, name, index)
              unless last_item?(index)
                resource.save!
                unless resource.subject?
                  self.class.send("update_#{resource.curriculum_type}s_level_position_for", resource.self_and_siblings)
                end
                parent = resource
                next
              end

              set_lesson_position(parent, resource)
            end

            update resource
          end
        end

        private

        def build_new_resource(parent, name, index)
          dir = directory[0..index]
          curriculum_type = parent.nil? ? Resource.hierarchy.first : parent.next_hierarchy_level
          resource = Resource.new(
            curriculum_type:,
            level_position: parent&.children&.size.to_i,
            metadata: metadata.to_a[0..index].to_h,
            parent_id: parent&.id,
            short_title: name,
            curriculum_id: Curriculum.default&.id
          )
          if last_item?(index)
            resource.teaser = teaser
            resource.title = title
          else
            resource.title = default_title(dir)
          end
          resource
        end

        def default_title(curr = nil)
          # MATH G1 U1 S2 Lesson 1
          curr ||= directory
          res = Resource.new(metadata:)
          # Breadcrumbs.new(res).title.split(" / ")[0...-1].push(curr.last.to_s.titleize).join(" ")
          Breadcrumbs.new(res).title.split(" / ")[0...curr.size].join(" ")
        end

        def grade
          @grade ||= context["grade"].to_s.downcase[/\d+/].presence || context["grade"].to_s.downcase
        end

        def last_item?(index)
          index == directory.size - 1
        end

        def lesson
          @lesson ||= numerize(context["lesson-number"])
        end

        def unit
          @unit ||= numerize(context["unit-id"])
        end

        def subject
          @subject ||= begin
            value = context["subject"]&.downcase
            if value.blank?
              nil
            elsif SUBJECTS.include?(value)
              value
            else
              raise "Unsupported subject #{value.inspect}; allowed: #{SUBJECTS.keys.join(', ')}"
            end
          end
        end

        def teaser
          context["teaser"]
        end

        def title
          context["title"].presence || default_title
        end

        def type
          context["type"]&.downcase
        end

        def section
          @section ||= numerize(context["section-number"])
        end

        def numerize(value)
          value = value.to_s.downcase
          value =~ RE_NUMBER ? value.to_i : value
        end

        def update(resource)
          return if resource.nil?

          # Update resource with document metadata
          resource.title = context["title"] if context["title"].present?
          resource.teaser = context["teaser"] if context["teaser"].present?
          resource.description = context["description"] if context["description"].present?
          resource.save

          resource
        end

        def set_lesson_position(parent, resource)
          raise "Cannot place lesson without parent resource (insufficient curriculum metadata: #{directory.inspect})" \
            if parent.nil?

          current_lesson = lesson.to_s[RE_NUM].to_i
          next_lesson = parent.children.detect do |r|
            # first lesson with a bigger lesson num
            r.metadata["lesson"].to_s[RE_NUM].to_i > current_lesson
          end
          next_lesson ? next_lesson.prepend_sibling(resource) : resource.save!
        end
      end
    end
  end
end

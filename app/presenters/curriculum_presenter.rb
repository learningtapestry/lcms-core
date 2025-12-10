# frozen_string_literal: true

# Simple presenter for Curriculum (resources tree)
class CurriculumPresenter
  include Rails.application.routes.url_helpers

  UNIT_LEVEL = Resource.hierarchy.index(:unit)

  def editor_props
    @editor_props ||= {
      form_url: admin_curriculum_path
    }
  end

  def parse_jstree_node(node)
    {
      id: node.id,
      text: element_text(node),
      children: node.children.any?,
      li_attr: { title: node.title }
    }
  end

  private

  def element_text(resource)
    case resource.curriculum_type
    when 'subject'
      resource.title
    when 'module', 'unit'
      resource.short_title&.upcase.presence || 'N/A'
    when 'grade'
      resource.short_title&.capitalize.presence || 'N/A'
    when 'lesson_set'
      "Lesson set #{resource.metadata['lesson_set']}"
    when 'lesson'
      "Lesson #{resource.metadata['lesson']}"
    else
      "Unknown curriculum type for: #{resource.title}"
    end
  end
end

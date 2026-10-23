# frozen_string_literal: true

class SectionPresenter < BasePresenter
  include HasGdocSource

  def section_number
    metadata["section_number"].presence || metadata["section"]
  end

  def section_title
    metadata["section_title"].presence || title
  end

  def section_title_spanish
    metadata["section_title_spanish"]
  end

  def unit_id
    metadata["unit_id"].presence || metadata["unit"]
  end

  # Section Overview body: the section-metadata description row as authored
  # HTML (the resource's own `description` column is a stripped summary).
  def overview_html
    metadata["description"].presence
  end

  # Lessons in this section, in curriculum order.
  def lessons
    @lessons ||= self_and_descendants_preordered.lessons.with_documents
                   .map { DocumentPresenter.new(it.document) }
  end

  # "1-2" (first and last lesson numbers in curriculum order), "3" for a
  # single lesson, nil when no lesson is numbered. Section Divider spec.
  def lesson_range
    numbers = lessons.filter_map { it.lesson_number.presence }
    [numbers.first, numbers.last].uniq.join("-").presence
  end

  # Divider note: "Lessons 1-2", or "Lesson 3" for a one-lesson section; nil
  # when no lesson is numbered.
  def lessons_label
    range = lesson_range
    return if range.nil?

    t(range.include?("-") ? "section.divider.lessons" : "section.divider.lesson", range:)
  end

  # Materials named in the section-metadata section-materials row, in authored
  # order, for the Section Materials pages of the Teacher Bundle to Print.
  def section_materials
    @section_materials ||= Material.in_listed_order(metadata["section_materials"]).map { MaterialPresenter.new(it) }
  end

  # Section Learning Targets: every lesson's learning-targets row, in lesson
  # order, one bullet per authored item (HTML snippets).
  def learning_targets
    @learning_targets ||= lessons.flat_map { learning_target_items(it.learning_targets) }
  end

  private

  # Splits one lesson's learning-targets into bullet items: its top-level list
  # items (a nested list stays inside its parent item, formatting intact), else
  # its non-blank paragraphs, else the whole value. A value without markup
  # (lessons imported before the row was kept as HTML) is escaped as text.
  def learning_target_items(html)
    fragment = Nokogiri::HTML.fragment(html.to_s)
    return [ERB::Util.html_escape(html.to_s.strip)].compact_blank if fragment.element_children.empty?

    top_level = ->(selector) { fragment.css(selector).reject { it.ancestors("li").any? }.presence }
    nodes = top_level.("li") || top_level.("p") || [fragment]
    nodes.reject { it.text.strip.empty? }.map { it.inner_html.strip }
  end
end

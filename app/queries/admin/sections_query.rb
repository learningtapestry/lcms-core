# frozen_string_literal: true

module Admin
  class SectionsQuery < BaseQuery
    def call
      @scope = Resource.sections.all
      @scope = apply_filters

      if @pagination.present?
        sorted_scope.paginate(page: @pagination[:page])
      else
        sorted_scope
      end
    end

    private

    def apply_filters
      @scope = @scope.filter_by_subject(q.subject) if q.subject.present?
      @scope = @scope.filter_by_grade(q.grade) if q.respond_to?(:grade) && q.grade.present?
      grades = Array.wrap(q.grades&.filter_map(&:presence))
      @scope = @scope.where_grade(grades) if q.respond_to?(:grades) && grades.any?
      @scope = @scope.where("resources.metadata ->> 'unit_id' = ?", q.unit_id.to_s) if q.respond_to?(:unit_id) && q.unit_id.present?
      @scope = @scope.where("resources.metadata ->> 'section_number' = ?", q.section_number.to_s) if q.respond_to?(:section_number) && q.section_number.present?
      if q.respond_to?(:search_term) && q.search_term.present?
        term = "%#{q.search_term}%"
        @scope = @scope.where("resources.title ILIKE ? OR resources.description ILIKE ?", term, term)
      end
      @scope
    end

    def sorted_scope
      @scope = @scope.ordered if q.sort_by.blank? || q.sort_by == "curriculum"
      @scope = @scope.order(updated_at: :desc) if q.sort_by == "last_update"
      @scope.distinct
    end
  end
end

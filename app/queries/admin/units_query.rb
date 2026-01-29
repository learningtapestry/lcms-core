# frozen_string_literal: true

module Admin
  # Usage:
  #   @units = Admin::UnitsQuery.call(query_params, page: params[:page])
  #
  class UnitsQuery < BaseQuery
    # Returns: ActiveRecord relation
    def call
      @scope = Resource.units.all # initial scope
      @scope = apply_filters

      if @pagination.present?
        sorted_scope.paginate(page: @pagination[:page])
      else
        sorted_scope
      end
    end

    private

    def apply_filters # rubocop:todo Metrics/AbcSize,  Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      @scope = @scope.filter_by_subject(q.subject) if q.subject.present?
      @scope = @scope.filter_by_grade(q.grade) if q.respond_to?(:grade) && q.grade.present?
      @scope = @scope.where_grade(q.grades&.compact) \
        if q.respond_to?(:grades) && Array.wrap(q.grades).reject(&:blank?).present?
      @scope = @scope.where_metadata(:module, q.module.to_s) if q.module.present?
      @scope
    end

    def sorted_scope
      @scope = @scope.ordered if q.sort_by.blank? || q.sort_by == "curriculum"
      @scope = @scope.order(updated_at: :desc) if q.sort_by == "last_update"
      @scope.distinct
    end
  end
end

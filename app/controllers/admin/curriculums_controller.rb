# frozen_string_literal: true

module Admin
  class CurriculumsController < AdminController
    def edit
      @curriculum = CurriculumPresenter.new
    end

    def children
      id = params[:id]
      resources =
        if id == "#"
          Resource.tree.ordered.roots
        else
          Array.wrap(Resource.tree.find(id)&.children)
        end

      render json: resources.map { |res| CurriculumPresenter.new.parse_jstree_node(res) }
    end

    def update
      @form = CurriculumForm.new(curriculum_update_params)
      if @form.save
        redirect_to edit_admin_curriculum_path,
                    notice: t(".success")
      else
        @curriculum = CurriculumPresenter.new
        render :edit, alert: t(".error")
      end
    end

    private

    def curriculum_update_params
      params.require(:curriculum).permit(:change_log)
    end
  end
end

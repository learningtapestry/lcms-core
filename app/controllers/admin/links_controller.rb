# frozen_string_literal: true

module Admin
  # The URL spreadsheet that `[url: url_id]` tags resolve against: imported
  # from a Google Sheet (LinksImportService) and listed here.
  class LinksController < AdminController
    def index
      @link_form = LinkForm.new
      load_links
    end

    def import
      @link_form = LinkForm.new(params.require(:link_form).permit(:link))
      if @link_form.save
        redirect_to admin_links_path, notice: t(".success", count: Link.count)
      else
        load_links
        render :index, status: :unprocessable_content
      end
    end

    private

    def load_links
      scope = Link.order(:identifier)
      scope = scope.search_by_identifier(params[:q]) if params[:q].present?
      @links = scope.paginate(page: params[:page])
    end
  end
end

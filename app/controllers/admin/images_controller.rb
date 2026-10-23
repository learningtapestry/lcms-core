# frozen_string_literal: true

module Admin
  # The image spreadsheet that `[image: id, size]` tags resolve against:
  # imported from a Google Sheet (ImagesImportService) and listed here.
  class ImagesController < AdminController
    def index
      @image_form = ImageForm.new
      load_images
    end

    def import
      @image_form = ImageForm.new(params.require(:image_form).permit(:link))
      if @image_form.save
        redirect_to admin_images_path, notice: t(".success", count: Image.count)
      else
        load_images
        render :index, status: :unprocessable_content
      end
    end

    private

    def load_images
      scope = Image.order(:identifier)
      scope = scope.search_by_identifier(params[:q]) if params[:q].present?
      @images = scope.paginate(page: params[:page])
    end
  end
end

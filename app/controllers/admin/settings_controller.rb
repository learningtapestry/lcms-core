module Admin
  class SettingsController < AdminController
    def index
      @groups = SettingsForm.new(params).groups
    end

    def update
      form = SettingsForm.new(params)
      if form.save
        redirect_to admin_settings_path, notice: t("admin.settings.updated.success")
      else
        # Re-render with the applied groups: form groups carry the operator's
        # submitted input + errors; flat groups read the rolled-back values.
        @groups = form.groups
        flash.now[:alert] = t("admin.settings.index.invalid")
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      group = SettingsForm.group_for(params[:key])
      return redirect_to admin_settings_path unless group

      group.reset(params[:key])
      redirect_to admin_settings_path, notice: t("admin.settings.deleted.success"), status: :see_other
    end

    def upload_image
      return head :unprocessable_entity unless params[:image].respond_to?(:tempfile)

      uploader = ImageUploader.new
      uploader.store!(params[:image])
      render json: { url: uploader.url }
    rescue CarrierWave::IntegrityError, CarrierWave::ProcessingError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end

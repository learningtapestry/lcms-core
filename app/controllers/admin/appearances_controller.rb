module Admin
  class AppearancesController < AdminController
    before_action :get_appearance_settings

    def get_appearance_settings
      @appearance_settings = Setting.get_multiple(SETTINGS[:appearance].keys)
      @setting_types = SETTINGS[:appearance]
    end

    def edit
      @setting_key = params[:key]
      @setting_value = @appearance_settings[@setting_key]
      @setting_type = SETTINGS[:appearance][@setting_key.to_sym]
      @setting_mime_types = SETTINGS_MIME_TYPES[@setting_type]
    end

    def update
      permitted_keys = SETTINGS[:appearance].keys.map(&:to_s)
      processed_params = process_logo_upload(params)
      new_settings = processed_params.permit(permitted_keys).to_h
      changes = new_settings.select { |key, value| @appearance_settings[key] != value }
      Setting.set_multiple(changes) if changes.any?
      redirect_to admin_appearance_path, notice: t("admin.appearance.updated.success")
    end

    def destroy
      delete_old_image_if_present(params[:key]) if image_setting?(params[:key])
      Setting.unset(params[:key])
      redirect_to admin_appearance_path, notice: t("admin.appearance.deleted.success"), status: :see_other
    end

    def upload_logo
      return head :unprocessable_entity unless params[:header_logo].respond_to?(:tempfile)

      uploader = LogoUploader.new
      uploader.store!(params[:header_logo])
      render json: { url: uploader.url }
    rescue CarrierWave::IntegrityError, CarrierWave::ProcessingError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def process_logo_upload(params)
      return params unless params[:header_logo].respond_to?(:tempfile)

      delete_old_image_if_present("header_logo")
      uploader = LogoUploader.new
      uploader.store!(params[:header_logo])
      processed = params.to_unsafe_h.merge(header_logo: uploader.url)
      ActionController::Parameters.new(processed)
    end

    def image_setting?(key)
      key.present? && SETTINGS.dig(:appearance, key.to_sym) == :image
    end

    def delete_old_image_if_present(setting_key)
      old_url = @appearance_settings[setting_key.to_sym] || @appearance_settings[setting_key]
      return if old_url.blank?

      if logo_stored_locally?(old_url)
        delete_local_logo(old_url)
      elsif logo_stored_on_s3?(old_url)
        delete_s3_logo(old_url)
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to delete old image: #{e.message}"
    end

    def logo_stored_locally?(url)
      url.to_s.start_with?("/uploads/settings/")
    end

    def logo_stored_on_s3?(url)
      url.to_s.include?("s3") || url.to_s.include?("amazonaws")
    end

    def delete_local_logo(url)
      path = Rails.root.join("public", url.to_s.delete_prefix("/"))
      FileUtils.rm_f(path) if path.exist?
    end

    def delete_s3_logo(url)
      uri = URI.parse(url)
      key = URI.decode_www_form_component(uri.path.delete_prefix("/"))
      return unless key.start_with?("uploads/settings/")

      S3Service.delete_object(key)
    end
  end
end

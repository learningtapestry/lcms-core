module Admin
  class SettingsController < AdminController
    before_action :load_all_settings, only: %i(index update)

    def index; end

    def update
      SETTINGS.each do |group, types|
        permitted_keys = types.keys.map(&:to_s)
        processed_params = process_image_uploads(params)
        new_settings = processed_params.permit(permitted_keys).to_h
        changes = new_settings.select { |key, value| @all_settings[group][key.to_sym] != value }

        next unless changes.any?

        current = Setting.get(group) || {}
        Setting.set(group, current.merge(changes))
      end

      redirect_to admin_settings_path, notice: t("admin.settings.updated.success")
    end

    def destroy
      key = params[:key]
      group = group_for_key(key)
      return redirect_to admin_settings_path unless group

      if image_setting?(group, key)
        old_url = Setting.get(group, include_defaults: true)&.dig(key.to_sym)
        ImageUploader.delete_by_url(old_url)
      end
      Setting.unset_within(group, key)
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

    private

    def load_all_settings
      @all_settings = Setting.get_multiple(SETTINGS.keys, include_defaults: true)
    end

    def group_for_key(key)
      SETTINGS.find { |_group, types| types.key?(key.to_sym) }&.first
    end

    def process_image_uploads(params)
      image_keys = SETTINGS.flat_map { |_group, types| types.select { |_k, v| v == :image }.keys }
      modified = params.to_unsafe_h

      image_keys.each do |key|
        next unless params[key].respond_to?(:tempfile)

        uploader = ImageUploader.new
        uploader.store!(params[key])
        modified[key] = uploader.url
      end

      ActionController::Parameters.new(modified)
    end

    def image_setting?(group, key)
      key.present? && SETTINGS.dig(group, key.to_sym) == :image
    end
  end
end

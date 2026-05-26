module Admin
  class SettingsController < AdminController
    before_action :load_all_settings, only: %i(index update)

    def index; end

    def update
      @form_invalid = false

      # Image uploads are processed once for ALL groups — `process_image_uploads`
      # walks every image key across SETTINGS, so calling it per-group would
      # re-upload the same file once per group.
      processed_params = process_image_uploads(params)

      SETTINGS.each do |group, types|
        if types == :form
          update_form_group(group)
        else
          update_flat_group(group, types, processed_params)
        end
      end

      if @form_invalid
        flash.now[:alert] = t("admin.settings.index.invalid")
        @all_settings = Settings.get_multiple(SETTINGS.keys, include_defaults: true)
        render :index, status: :unprocessable_entity
      else
        redirect_to admin_settings_path, notice: t("admin.settings.updated.success")
      end
    end

    def destroy
      key = params[:key]
      group = group_for_key(key)
      return redirect_to admin_settings_path unless group

      if form_group?(group)
        Settings.set(group, Settings::DEFAULTS[group])
      else
        if image_setting?(group, key)
          old_url = Settings.get(group, include_defaults: true)&.dig(key.to_sym)
          ImageUploader.delete_by_url(old_url)
        end
        Settings.unset_within(group, key)
      end
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

    def update_flat_group(group, types, processed_params)
      permitted_keys = types.keys.map(&:to_s)
      new_settings = processed_params.permit(permitted_keys).to_h
      changes = new_settings.select { |key, value| @all_settings[group][key.to_sym] != value }

      return unless changes.any?

      current = Settings.get(group) || {}
      Settings.set(group, current.merge(changes))
    end

    # Validates and persists a structured (:form) group through its model
    # (e.g. Setting::Pdf). On failure the submitted model is kept in
    # @form_models so the form can re-render the operator's input + errors.
    def update_form_group(group)
      return unless params.key?(group)

      model = build_form_model(group, submitted: params[group].to_unsafe_h)
      if model.valid?
        Settings.set(group, model.to_h)
      else
        @form_models[group] = model
        @form_invalid = true
      end
    end

    def load_all_settings
      @all_settings = Settings.get_multiple(SETTINGS.keys, include_defaults: true)
      @form_models = form_groups.index_with { |group| build_form_model(group) }
    end

    def build_form_model(group, submitted: nil)
      form_model_class(group).new(stored: Settings.get(group), submitted: submitted)
    end

    def form_model_class(group)
      "Setting::#{group.to_s.camelize}".constantize
    end

    def form_groups
      SETTINGS.select { |_group, types| types == :form }.keys
    end

    def form_group?(group)
      SETTINGS[group&.to_sym] == :form
    end

    def group_for_key(key)
      SETTINGS.find do |group, types|
        types.is_a?(Hash) ? types.key?(key.to_sym) : group.to_s == key
      end&.first
    end

    def process_image_uploads(params)
      image_keys = SETTINGS.flat_map do |_group, types|
        types.is_a?(Hash) ? types.select { |_k, v| v == :image }.keys : []
      end
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
      types = SETTINGS[group]
      key.present? && types.is_a?(Hash) && types[key.to_sym] == :image
    end
  end
end

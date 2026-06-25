# frozen_string_literal: true

class SettingsForm
  # A structured group (SETTINGS value `:form`) backed by a virtual model
  # `Setting::<Group>` (e.g. Setting::Pdf, Setting::AdminViewLinks) that casts
  # and validates a nested value tree. Editing is value-only; the model is the
  # source of truth for the schema and errors.
  class FormGroup < BaseGroup
    def form?
      true
    end

    # The model for the view: the submitted model (with the operator's input and
    # validation errors) once #prepare has run, otherwise the stored state.
    def model
      @submitted_model || stored_model
    end

    # Build the submitted model so it can be validated before anything is
    # persisted. No write here — that happens in #commit.
    def prepare(params)
      @submitted_model = build_model(submitted: params[key].to_unsafe_h) if params.key?(key)
    end

    def commit
      Settings.set(key, @submitted_model.to_h) if @submitted_model
    end

    # Only a submitted group can be invalid; an untouched group never blocks a
    # save of the other groups.
    def valid?
      @submitted_model.nil? || @submitted_model.valid?
    end

    def reset(_sub_key = nil)
      defaults = Settings::DEFAULTS[key]
      defaults ? Settings.set(key, defaults) : Settings.unset(key)
    end

    def to_partial_path
      "admin/settings/groups/form"
    end

    private

    def stored_model
      @stored_model ||= build_model
    end

    def build_model(submitted: nil)
      model_class.new(stored: Settings.get(key), submitted: submitted)
    end

    def model_class
      "Setting::#{key.to_s.camelize}".constantize
    end
  end
end

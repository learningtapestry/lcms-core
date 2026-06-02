# frozen_string_literal: true

class Setting
  # Virtual (non-persisted) model for the :pdf setting. It is the single source
  # of truth for the editable PDF geometry schema: it casts and validates the
  # KNOWN fields and passes any other keys through untouched (forks may store
  # extra content-type blocks or keys — e.g. gutter, header_margin). Used by
  # Admin::SettingsController to validate input and by the settings form to
  # render typed fields.
  #
  # The structure is content-type-keyed (`default`, `handout`, and any fork
  # block). RULES are expressed relative to a content-type block, so the same
  # rules apply to every block. Editing is value-only: existing leaves can be
  # changed, but keys are never added or removed (overlay! only touches leaves
  # already present in the stored structure).
  class Pdf
    include ActiveModel::Model

    LENGTH_FORMAT = /\A\d+(\.\d+)?(in|pt|cm|mm|px)\z/

    # Path (within a content-type block) => casting/validation rule.
    RULES = {
      %i(dpi) => { type: :integer, min: 1 },
      %i(image_dpi) => { type: :integer, min: 1 },
      %i(header) => { type: :boolean },
      %i(name_date) => { type: :boolean },
      %i(orientation) => { type: :string, in: %w(portrait landscape) },
      %i(margin top) => { type: :length },
      %i(margin right) => { type: :length },
      %i(margin bottom) => { type: :length },
      %i(margin left) => { type: :length },
      %i(padding right) => { type: :integer, min: 0 },
      %i(padding left) => { type: :integer, min: 0 }
    }.freeze

    BOOLEAN = ActiveModel::Type::Boolean.new

    # Top-level (not content-type-scoped) key: the default PDF renderer. Blank
    # means "use the system fallback". Validated against the registered
    # renderers and rendered as a dedicated select in the form.
    DEFAULT_RENDERER_KEY = "default_renderer"

    attr_reader :data

    validate :validate_known_fields
    validate :validate_default_renderer

    def initialize(stored: nil, submitted: nil)
      base = (stored.presence || Settings::DEFAULTS[:pdf]).deep_stringify_keys
      @data = base.deep_dup
      overlay!(submitted.deep_stringify_keys) if submitted.present?
    end

    def to_h
      @data
    end

    # Returns the input descriptor for the view given a within-setting path
    # (e.g. %w(default margin top)) and the current value. Known paths use the
    # declared rule; unknown (fork) paths fall back to type inference.
    def field_descriptor(path, value)
      return { input: :renderer_select } if path.map(&:to_s) == [DEFAULT_RENDERER_KEY]

      rule = RULES[rule_key(path)]
      return inferred_descriptor(value) unless rule

      case rule[:type]
      when :integer then { input: :number }
      when :boolean then { input: :checkbox }
      when :string then rule[:in] ? { input: :select, options: rule[:in] } : { input: :text }
      else { input: :text }
      end
    end

    def error_for(path)
      errors[path.join(".")].first
    end

    private

    def rule_key(path)
      path[1..].map(&:to_sym)
    end

    def inferred_descriptor(value)
      case value
      when Integer, Float then { input: :number }
      when true, false then { input: :checkbox }
      else { input: :text }
      end
    end

    def overlay!(submitted)
      @data = deep_overlay(@data, submitted, [])
    end

    # Walks the existing structure and replaces only leaves that the submitted
    # params also carry. Submitted keys absent from the structure are ignored,
    # so the operator cannot add (or remove) fields.
    def deep_overlay(current, submitted, path)
      current.each_with_object({}) do |(key, value), result|
        sub = submitted.is_a?(Hash) ? submitted[key] : nil
        result[key] =
          if value.is_a?(Hash)
            deep_overlay(value, sub, path + [key])
          elsif submitted.is_a?(Hash) && submitted.key?(key)
            cast_leaf(path + [key], sub, value)
          else
            value
          end
      end
    end

    def cast_leaf(path, submitted_value, current_value)
      rule = RULES[rule_key(path)]
      return cast_by_type(rule[:type], submitted_value) if rule

      cast_by_inference(current_value, submitted_value)
    end

    def cast_by_type(type, value)
      case type
      when :integer then to_integer(value)
      when :boolean then BOOLEAN.cast(value)
      else value.to_s
      end
    end

    def cast_by_inference(current_value, value)
      case current_value
      when Integer then to_integer(value)
      when Float then to_float(value)
      when true, false then BOOLEAN.cast(value)
      else value.to_s
      end
    end

    def to_integer(value)
      Integer(value.to_s, 10)
    rescue ArgumentError, TypeError
      value
    end

    def to_float(value)
      Float(value)
    rescue ArgumentError, TypeError
      value
    end

    def validate_known_fields
      @data.each do |content_type, block|
        next unless block.is_a?(Hash)

        RULES.each do |rkey, rule|
          value = block.dig(*rkey.map(&:to_s))
          next if value.nil?

          check_value("#{content_type}.#{rkey.join('.')}", value, rule)
        end
      end
    end

    # Blank is allowed (means "use the system fallback"); any other value must
    # name a registered renderer so the saved setting can never point at a
    # backend that does not exist.
    def validate_default_renderer
      value = @data[DEFAULT_RENDERER_KEY]
      return if value.blank?

      allowed = available_renderers.map(&:to_s)
      return if allowed.include?(value.to_s)

      errors.add(DEFAULT_RENDERER_KEY, "must be one of: #{allowed.join(', ')}")
    end

    def available_renderers
      Exporters::Pdf::RendererRegistry.available
    end

    def check_value(path, value, rule)
      case rule[:type]
      when :integer then check_integer(path, value, rule)
      when :boolean then errors.add(path, "must be true or false") unless [true, false].include?(value)
      when :length then errors.add(path, "must be a length such as 0.5in or 12pt") unless valid_length?(value)
      when :string then check_inclusion(path, value, rule)
      end
    end

    def check_integer(path, value, rule)
      unless value.is_a?(Integer)
        errors.add(path, "must be a whole number")
        return
      end

      errors.add(path, "must be at least #{rule[:min]}") if rule[:min] && value < rule[:min]
    end

    def check_inclusion(path, value, rule)
      return unless rule[:in]

      errors.add(path, "must be one of: #{rule[:in].join(', ')}") unless rule[:in].include?(value)
    end

    def valid_length?(value)
      value.is_a?(String) && value.match?(LENGTH_FORMAT)
    end
  end
end

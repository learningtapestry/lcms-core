# frozen_string_literal: true

class Setting
  # Base class for the virtual (non-persisted) settings models that back the
  # admin form editor (the `:form` SETTINGS type). A subclass declares a
  # `RULES` map of absolute path => casting/validation rule; the base provides
  # casting, validation, form descriptors, and edit-only overlay semantics.
  #
  # Editing is value-only: existing leaves can be changed, but keys are never
  # added or removed (overlay only touches leaves already present in the
  # stored structure). Values at paths without a rule are preserved untouched
  # and cast by inference (fork passthrough).
  #
  # Supported rule types:
  #   :integer    { min: }          number input
  #   :boolean                      checkbox
  #   :string     { in: [...] }     text, or select when :in is given
  #   :length                       text, CSS length (e.g. 0.5in)
  #   :list       { item: :string } textarea, one element per line -> Array
  #   :class_name                   text, must resolve to a defined constant
  class Base
    include ActiveModel::Model

    RULES = {}.freeze
    LENGTH_FORMAT = /\A\d+(\.\d+)?(in|pt|cm|mm|px)\z/
    BOOLEAN = ActiveModel::Type::Boolean.new

    attr_reader :data

    validate :validate_known_fields

    def initialize(stored: nil, submitted: nil)
      base = (stored.presence || defaults).deep_stringify_keys
      @data = base.deep_dup
      overlay!(submitted.deep_stringify_keys) if submitted.present?
    end

    def to_h
      @data
    end

    def field_descriptor(path, value)
      rule = rule_for(path)
      return inferred_descriptor(value) unless rule

      case rule[:type]
      when :integer then { input: :number }
      when :boolean then { input: :checkbox }
      when :list then { input: :list }
      when :string, :class_name then rule[:in] ? { input: :select, options: rule[:in] } : { input: :text }
      else { input: :text }
      end
    end

    def error_for(path)
      errors[path.join(".")].first
    end

    private

    def defaults
      Settings::DEFAULTS[setting_key] || {}
    end

    def setting_key
      self.class.name.demodulize.underscore.to_sym
    end

    def rule_for(path)
      self.class::RULES[path.map(&:to_sym)]
    end

    def inferred_descriptor(value)
      case value
      when Array then { input: :list }
      when Integer, Float then { input: :number }
      when true, false then { input: :checkbox }
      else { input: :text }
      end
    end

    def overlay!(submitted)
      @data = deep_overlay(@data, submitted, [])
    end

    # Replaces only leaves the submitted params also carry; keys absent from
    # the stored structure are ignored, so the operator edits values but
    # cannot add or remove fields.
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
      rule = rule_for(path)
      return cast_by_type(rule[:type], submitted_value) if rule

      cast_by_inference(current_value, submitted_value)
    end

    def cast_by_type(type, value)
      case type
      when :integer then to_integer(value)
      when :boolean then BOOLEAN.cast(value)
      when :list then to_list(value)
      else value.to_s
      end
    end

    def cast_by_inference(current_value, value)
      case current_value
      when Array then to_list(value)
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

    def to_list(value)
      return value if value.is_a?(Array)

      value.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
    end

    def validate_known_fields
      walk_leaves(@data, []) do |path, value|
        rule = rule_for(path)
        next if rule.nil? || value.nil?

        check_value(path.join("."), value, rule)
      end
    end

    def walk_leaves(node, path, &block)
      node.each do |key, value|
        child = path + [key.to_s]
        if value.is_a?(Hash)
          walk_leaves(value, child, &block)
        else
          block.call(child, value)
        end
      end
    end

    def check_value(path, value, rule)
      case rule[:type]
      when :integer then check_integer(path, value, rule)
      when :boolean then errors.add(path, "must be true or false") unless [true, false].include?(value)
      when :length then errors.add(path, "must be a length such as 0.5in or 12pt") unless valid_length?(value)
      when :list then check_list(path, value)
      when :class_name then check_class_name(path, value)
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

    def check_list(path, value)
      unless value.is_a?(Array)
        errors.add(path, "must be a list")
        return
      end

      errors.add(path, "must not contain blank entries") if value.any? { |item| !item.is_a?(String) || item.blank? }
    end

    def check_class_name(path, value)
      errors.add(path, "is not a known class") unless value.is_a?(String) && value.safe_constantize
    end

    def valid_length?(value)
      value.is_a?(String) && value.match?(LENGTH_FORMAT)
    end
  end
end

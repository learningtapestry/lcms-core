# frozen_string_literal: true

module DocTemplate
  module Objects
    class Base
      include ActiveModel::Model
      include ActiveModel::Attributes
      include DocTemplate::Objects::AttributeAccess

      attribute :subject, :string, default: SUBJECT_DEFAULT

      def initialize(attrs = {})
        known = self.class.attribute_names.map(&:to_s)
        super(attrs.to_h.select { |k, _| known.include?(k.to_s) })
      end

      def as_json(options = nil)
        attributes
      end

      class << self
        def build_from(data)
          new prepare_data(data)
        end

        #
        # Splits the text by separator removing empty parts
        #
        # @param text [String] text to be split
        # @param separator [String]
        # @return [Array] array of parts
        #
        def split_field(text, separator = DocTemplate::Tables::Base::SPLIT_REGEX)
          text.to_s
              .split(separator)
              .map(&:squish).reject(&:blank?)
        end

        def coerce_boolean(value)
          return value unless value.is_a?(String)

          case value.downcase
          when "yes" then true
          when "no" then false
          else value
          end
        end

        protected

        def prepare_data(data)
          copy = Marshal.load Marshal.dump(data)
          copy.deep_transform_keys { |k| k.to_s.underscore.downcase }
              .transform_values { |v| coerce_boolean(v) }
        end

        #
        # Corresponding error occurred after upgrading `oj` gem
        #
        def to_json(*_args)
          send :as_json
        end
      end
    end
  end
end

# frozen_string_literal: true

module DocTemplate
  module Objects
    class Base
      include Virtus::InstanceMethods::Constructor
      include Virtus.model

      attribute :subject, String, default: SUBJECT_DEFAULT

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

        protected

        def prepare_data(data)
          copy = Marshal.load Marshal.dump(data)
          copy.deep_transform_keys { |k| k.to_s.underscore.downcase }
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

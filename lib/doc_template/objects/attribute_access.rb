# frozen_string_literal: true

module DocTemplate
  module Objects
    module AttributeAccess
      def [](key)
        public_send(key)
      end

      def []=(key, value)
        public_send("#{key}=", value)
      end
    end
  end
end

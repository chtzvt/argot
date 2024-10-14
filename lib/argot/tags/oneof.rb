module Argot
  module Tag
    class OneOf < Base
      tag_name "oneof"
      tag_name "one"

      def initialize
        super
        @options = []
      end

      def configure(options)
        @options = options
      end
    end
  end
end

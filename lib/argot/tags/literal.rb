module Argot
  module Tag
    class Literal < Base
      tag_name "literal"
      tag_name "l"
      annotates :value

      def initialize
        @expected_value = nil
      end

      def configure(value)
        @expected_value = value
      end

      def expectation
        "'#{@expected_value}'"
      end

      def validate(value)
        value == @expected_value
      end
    end
  end
end

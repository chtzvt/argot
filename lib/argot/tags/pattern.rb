module Argot
  module Tag
    class Pattern < Base
      tag_name "rexpr"
      tag_name "x"
      annotates :key_or_value

      def initialize
        super
        @regex = nil
      end

      def configure(pattern)
        @regex = Regexp.new(pattern)
      end

      def expectation
        "a match for the regular expression '#{@regex.source}'"
      end

      def validate(value)
        return false unless value.is_a?(String)

        value.match?(@regex)
      end
    end
  end
end

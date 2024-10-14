module Argot
  module Tag
    class Type < Base
      tag_name "type"
      tag_name "t"
      annotates :value

      def initialize
        super
        @expected_types = nil
      end

      def configure(type_name)
        @expected_types = case type_name.downcase
        when "string"
          [String]
        when "integer"
          [Integer]
        when "float"
          [Float]
        when "array"
          [Array]
        when "hash", "map"
          [Hash]
        when "boolean"
          [TrueClass, FalseClass]
        else
          []
        end
      end

      def expectation
        return "Boolean" if @expected_types.length == 2

        @expected_types.first.name
      end

      def validate(value)
        return false if @expected_types.empty?

        @expected_types.any? { |t| value.is_a?(t) }
      end
    end
  end
end

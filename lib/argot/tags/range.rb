module Argot
  module Tag
    class Range < Base
      tag_name "range"
      tag_name "rg"
      annotates :value

      def initialize
        super
        @range = nil
      end

      def configure(range_str)
        # Parse the range string using a regex
        # Supports formats like '1..10', '1...10', '1-10', '1 to 10'
        if range_str =~ /\A\s*(\d+)\s*(\.\.\.?|-|to)\s*(\d+)\s*\z/
          start_num = Regexp.last_match(1).to_i
          operator = Regexp.last_match(2)
          end_num = Regexp.last_match(3).to_i

          inclusive = ["..", "-", "to"].include?(operator)
          exclusive = operator == "..."

          @range = if inclusive
            (start_num..end_num)
          elsif exclusive
            (start_num...end_num)
          end
        else
          @range = nil
        end
      end

      def expectation
        "a value between #{@range.min} and #{@range.max}"
      end

      def validate(value)
        return false if @range.nil?

        return false unless value.is_a?(Numeric)

        @range.cover?(value)
      end
    end
  end
end

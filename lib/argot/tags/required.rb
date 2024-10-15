module Argot
  module Tag
    class Required < Base
      tag_name "required"
      tag_name "r"

      annotates :key

      def validate(value)
        true
      end
    end
  end
end

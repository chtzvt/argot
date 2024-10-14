module Argot
  module Tag
    class Optional < Base
      tag_name "optional"
      tag_name "o"
      annotates :key

      def validate(value)
        # Optional fields do not produce errors if missing
        true
      end
    end
  end
end

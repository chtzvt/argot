module Argot
  module Tag
    class Required < Base
      tag_name "required"
      tag_name "r"

      annotates :key

      def validate(schema_node, document_node)
        key = schema_node.path.join(".")
        unless document_node
          Argot::Annotation.new(
            title: "Missing Required Field",
            message: "Field '#{key}' is required but missing",
            level: Annotation::FAILURE,
            location: schema_node.location
          )
        end
      end
    end
  end
end

module Argot
  module Tag
    @tags = {}
    @global_uri = "tag:argot.packfiles.io,2024"

    def self.register(klass)
      full_tag = "#{klass.uri}:#{klass.tag_name}"
      @tags[full_tag] = Object.const_get(klass.name)
    end

    def self.for(tag)
      @tags[tag]&.new
    end

    def self.tags
      @tags
    end

    def self.global_uri
      @global_uri
    end

    def self.global_uri=(uri)
      @global_uri = uri
    end

    class Base
      class << self
        attr_reader :annotation_type

        def annotates_key?
          @annotation_type == :key || @annotation_type == :key_or_value
        end

        def annotates_value?
          @annotation_type == :value || @annotation_type == :key_or_value
        end

        def annotates(arg)
          @annotation_type = arg if %i[key value key_or_value].include?(arg)
        end

        def tag_name(name = nil)
          if name
            @tag_name = name
            Argot::Tag.register(self)
          end
          @tag_name
        end

        def uri(uri = nil)
          return Argot::Tag.global_uri if uri.nil?

          @uri = "tag:" + uri
        end
      end

      def annotation_type
        self.class.annotation_type
      end

      def annotates_key?
        self.class.annotates_key?
      end

      def annotates_value?
        self.class.annotates_value?
      end

      def configure(value)
      end
    end
  end
end

Dir[File.join(__dir__, "tags", "*.rb")].each { |file| require file }

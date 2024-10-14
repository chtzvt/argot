module Argot
  module Schema
    def self.register(id, schema_yaml)
      @schemas ||= {}
      @schemas[id.is_a?(Symbol) ? id : id.to_sym] = load(schema_yaml)
    end

    def self.for(id)
      @schemas[id]&.dup
    end

    def self.load(schema_yaml)
      schema = Schema::Parser.parse(schema_yaml)
      ruleset = Schema::Ruleset.new
      Schema::Compiler.compile(schema.tree, ruleset)
      ruleset
    end

    class Ruleset
      attr_reader :rules

      def initialize
        @rules = Hash.new { |hash, key| hash[key] = {key: [], value: []} }
      end

      def add(type, tag, path)
        case type
        when :key
          @rules[path][:key] << tag
        when :value
          @rules[path][:value] << tag
        end
      end

      def permit_path?(path)
        return false if path.empty? || path.nil?

        @rules.each_key do |key_path|
          return true if match_path?(key_path, path)
        end

        false
      end

      def permit_value?(path, value)
        rule = lookup(path)

        return false if rule.nil?

        rule[:value].any? { |tag| tag.validate(value) }
      end

      def lookup(path)
        @rules.each do |key_path, rule_set|
          return rule_set if match_path?(key_path, path)
        end
        nil
      end

      def paths
        @rules.keys
      end

      def subkeys(partial_path)
        return @rules.keys if partial_path.empty?

        @rules.keys.map do |key_path|
          if match_subpath?(key_path, partial_path)
            next_element = key_path[partial_path.size]
            [next_element] if next_element
          end
        end.compact!.uniq
      end

      def required_path?(path)
        parent_path = path.take((path.length >= 1) ? path.length - 1 : 0)
        parent_rule_set = lookup(parent_path)
        rule_set = lookup(path)

        if parent_rule_set.nil? && rule_set.nil?
          false
        elsif parent_rule_set.nil? && rule_set[:key].any? { |tag| tag.is_a?(Argot::Tag::Required) }
          true
        elsif !parent_rule_set.nil? && parent_rule_set[:key].any? { |tag| tag.is_a?(Argot::Tag::Optional) } && !rule_set.nil? && rule_set[:key].any? { |tag| tag.is_a?(Argot::Tag::Required) }
          true
        else
          false
        end
      end

      def match_path?(key_path, lookup_path)
        return false unless key_path.size == lookup_path.size

        key_path.zip(lookup_path).all? do |key_part, lookup_part|
          case key_part
          when String
            key_part == lookup_part
          when Regexp
            if lookup_part.is_a?(String)
              key_part.match?(lookup_part)
            elsif lookup_part.is_a?(Regexp)
              key_part == lookup_part
            end
          else
            false
          end
        end
      end

      def match_subpath?(key_path, partial_path)
        return false unless key_path.size > partial_path.size

        key_path.first(partial_path.size).zip(partial_path).all? do |key_part, partial_part|
          case key_part
          when String
            key_part == partial_part
          when Regexp
            if partial_part.is_a?(String)
              key_part.match?(partial_part)
            elsif partial_part.is_a?(Regexp)
              key_part == partial_part
            end
          else
            false
          end
        end
      end
    end

    class Compiler
      def self.compile(node, ruleset)
        return unless node.is_a? Argot::Schema::Node

        return unless node.value.is_a?(Array)

        node.value.each do |child|
          next if child.is_a? Argot::Schema::Node

          child_node_annotation = child.first
          child_node = child.last

          if child_node_annotation.tag_is_a?(Tag::Pattern)
            ruleset.add(:key, Tag::Optional.new, child_node.path)
          else
            ruleset.add(:key, child_node_annotation.tag, child_node.path)
          end

          if child_node.tag?
            if child_node.tag_is_a?(Argot::Tag::OneOf)
              child_node.value.each do |oneof_opt|
                if oneof_opt.tag?
                  ruleset.add(:value, oneof_opt.tag, oneof_opt.path)
                else
                  compile(oneof_opt, ruleset)
                end
              end
            else
              ruleset.add(:value, child_node.tag, child_node.path)
            end
          end

          compile(child_node, ruleset)
        end
      end
    end

    class Node
      attr_accessor :value, :path
      attr_reader :tag, :location

      def initialize(value: nil, tag: nil, location: nil, path: [])
        @value = value
        self.tag = tag
        configure_tag!
        self.location = location
        @path = path
      end

      def tag?
        !@tag.nil?
      end

      def tag_is_a?(klass)
        @tag.is_a?(klass)
      end

      def configure_tag!
        @tag.configure(@value) if tag?
      end

      def tag=(tag)
        @tag = Argot::Tag.for(tag)
      end

      def location=(loc)
        @location = Argot::Location.new(**loc)
      end
    end

    class Parser < ::Psych::Handler
      attr_reader :tree, :locations, :current_path

      class << self
        def parse(schema_yaml)
          handler = Argot::Schema::Parser.new
          parser = Psych::Parser.new(handler)
          parser.parse(schema_yaml)
          handler
        end
      end

      def initialize
        super
        @context = []
        @tree = nil
        @current_path = []
        @locations = {}
        @scalar_scanner = build_safe_scalar_scanner
      end

      def build_safe_scalar_scanner
        class_loader = Psych::ClassLoader::Restricted.new([], [])
        Psych::ScalarScanner.new(class_loader)
      end

      def context_empty?
        @context.empty?
      end

      def current_context
        @context.last
      end

      def in_sequence?
        current_context&.key?(:sequence)
      end

      def in_mapping?
        current_context&.key?(:mapping)
      end

      def push_path(val)
        @current_path.push(val)
      end

      def pop_path
        @current_path.pop
      end

      def dup_path
        @current_path.dup
      end

      def event_location(start_line, start_column, end_line, end_column)
        @current_location = {
          start_line: start_line + 1,
          end_line: end_line + 1,
          start_column: start_column + 1,
          end_column: end_column + 1
        }
      end

      def start_mapping(anchor, tag, implicit, style)
        @context.push({mapping: [], tag: tag, key: nil})
      end

      def end_mapping
        mapping = @context.pop

        node = Node.new(
          value: mapping[:mapping],
          tag: mapping[:tag],
          location: @current_location.dup,
          path: dup_path
        )

        if context_empty?
          @tree = node
          return
        end

        if in_sequence?
          current_context[:sequence] << node
        elsif in_mapping?
          if current_context[:key].nil?
            raise Argot::Unprocessable, "Unexpected state in end_mapping"
          else
            current_context[:mapping] << [current_context[:key], node]
            current_context[:key] = nil
            pop_path
          end
        else
          raise Argot::Unprocessable, "Unknown context in end_mapping"
        end
      end

      def scalar(value, anchor, tag, plain, quoted, style)
        parsed_value = parse_scalar(value)

        node = Node.new(
          value: parsed_value,
          tag: tag,
          location: @current_location.dup,
          path: dup_path
        )

        if context_empty?
          @tree = node
          return
        end

        if in_sequence?
          current_context[:sequence] << node
          return
        end

        if in_mapping?
          if current_context[:key].nil?
            # We are processing a key
            if node.tag_is_a?(Tag::Pattern)
              push_path Regexp.new(parsed_value)
            else
              push_path parsed_value.to_s
            end

            location_key = @current_path.join(".")
            @locations[location_key] = node.location

            current_context[:key] = node
          else
            # We are processing a value

            current_context[:mapping] << [current_context[:key], node]
            current_context[:key] = nil
            pop_path
          end
          return
        end

        raise Argot::Unprocessable, "Unknown context in scalar"
      end

      def start_sequence(anchor, tag, implicit, style)
        @context.push({sequence: [], tag: tag})
      end

      def end_sequence
        sequence = @context.pop

        node = Node.new(
          value: sequence[:sequence],
          tag: sequence[:tag],
          location: @current_location.dup,
          path: dup_path
        )

        if context_empty?
          @tree = node
          return
        end

        if in_sequence?
          current_context[:sequence] << node
        elsif in_mapping?
          if current_context[:key].nil?
            raise Argot::Unprocessable, "Unexpected state in end_sequence"
          else
            current_context[:mapping] << [current_context[:key], node]
            current_context[:key] = nil
            pop_path
          end
        else
          raise Argot::Unprocessable, "Unknown context in end_sequence"
        end
      end

      private

      def parse_scalar(value)
        @scalar_scanner.tokenize(value)
      rescue ArgumentError, Psych::SyntaxError
        value.to_s
      end
    end
  end
end

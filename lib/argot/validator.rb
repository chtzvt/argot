module Argot
  class Validator < Psych::Handler
    attr_reader :errors

    class << self
      def parse_and_validate(ruleset, file_content, file_name: "input")
        handler = Argot::Validator.new(ruleset, file_name)
        parser = Psych::Parser.new(handler)
        parser.parse(file_content)
        handler.validate_document
        handler
      end

      def load(ruleset, file_content, file_name: "input", **)
        handler = parse_and_validate(ruleset, file_content, file_name: file_name)

        handler.safe_load(**)
      end
    end

    def initialize(ruleset, file_name)
      super()
      @ruleset = ruleset
      @file_name = file_name || "input"
      @context = []
      @current_path = []
      @encountered_paths = {}
      @missing_keys = {}
      @errors = []
      @current_location = {}
      @scalar_scanner = build_safe_scalar_scanner

      @stream_node = Psych::Nodes::Stream.new
      @document_node = Psych::Nodes::Document.new([], [], true)
      @stream_node.children << @document_node
    end

    def build_safe_scalar_scanner
      class_loader = Psych::ClassLoader::Restricted.new([], [])
      Psych::ScalarScanner.new(class_loader)
    end

    def errors?
      !@errors.empty?
    end

    def tree
      @stream_node
    end

    def safe_load(permitted_classes: [], permitted_symbols: [], aliases: false, filename: nil, fallback: nil, symbolize_names: false, freeze: false, strict_integer: false, ignore_validation_errors: false)
      return nil if errors? && !ignore_validation_errors
      return fallback unless tree

      class_loader = Psych::ClassLoader::Restricted.new(permitted_classes.map(&:to_s), permitted_symbols.map(&:to_s))

      scanner = Psych::ScalarScanner.new class_loader, strict_integer: strict_integer

      visitor = if aliases
        Psych::Visitors::ToRuby.new scanner, class_loader, symbolize_names: symbolize_names, freeze: freeze
      else
        Psych::Visitors::NoAliasRuby.new scanner, class_loader, symbolize_names: symbolize_names, freeze: freeze
      end

      begin
        result = visitor.accept tree
      rescue Psych::DisallowedClass => e
        raise Argot::MaliciousInput, e.message
      end

      result
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
      mapping = Psych::Nodes::Mapping.new(anchor, tag, implicit, style)
      push_context({node: mapping, key: nil})
    end

    def end_mapping
      mapping = pop_context[:node]

      if context_empty?
        append_tree mapping
        return
      end

      if in_sequence?
        append_child mapping
      elsif in_mapping?
        raise Argot::Unprocessable, "Unexpected state in end_mapping" if current_context[:key].nil?

        append_child current_context[:key]
        append_child mapping
        current_context[:key] = nil
        pop_path
      end
    end

    def scalar(value, anchor, tag, plain, quoted, style)
      scalar = Psych::Nodes::Scalar.new(value, anchor, tag, plain, quoted, style)

      if in_sequence?
        append_child scalar
        validate_node scalar
        pop_path
      elsif in_mapping?
        if current_context[:key].nil?
          push_path value
          current_context[:key] = scalar
        else
          append_child current_context[:key]
          append_child scalar
          validate_node scalar

          current_context[:key] = nil
          pop_path
        end
      else
        raise Argot::Unprocessable, "Unknown context in scalar"
      end
    end

    def start_sequence(anchor, tag, implicit, style)
      sequence = Psych::Nodes::Sequence.new(anchor, tag, implicit, style)
      push_context({node: sequence})
    end

    def end_sequence
      sequence = pop_context[:node]

      if context_empty?
        append_tree sequence
      elsif in_sequence?
        append_child sequence
      elsif in_mapping?
        raise Argot::Unprocessable, "Unexpected state in end_sequence" if current_context[:key].nil?

        append_child current_context[:key]
        append_child sequence
        current_context[:key] = nil
      end
    end

    def validate_document
      # Check for required keys
      @ruleset.paths.each do |ruleset_path|
        parent_path = ruleset_path.take(ruleset_path.length - 1)

        if @ruleset.required_path?(ruleset_path) && !encountered_path?(ruleset_path) && encountered_path?(parent_path)
          emit_missing_key_error(ruleset_path)
        end
      end

      # Check for optionally required keys (required keys that are children of an optional parent key)
      @encountered_paths.each_key do |tracked_path|
        subkey_paths = @ruleset.subkeys(tracked_path)

        subkey_paths.each do |subkey_path_part|
          subkey_path = tracked_path + subkey_path_part
          rule_set = @ruleset.lookup(subkey_path)

          next unless rule_set&.key?(:key)

          emit_missing_key_error(subkey_path) if @ruleset.required_path?(subkey_path) && !encountered_path?(subkey_path)
        end
      end
    end

    private

    def in_sequence?
      current_context[:node].is_a?(Psych::Nodes::Sequence)
    end

    def in_mapping?
      current_context[:node].is_a?(Psych::Nodes::Mapping)
    end

    def append_child(node)
      return unless @ruleset.permit_path?(@current_path)

      @encountered_paths[@current_path.dup] = @current_location.dup unless @encountered_paths.key?(@current_path)
      current_context[:node].children << node
    end

    def append_tree(node)
      @document_node.children << node
    end

    def context_empty?
      @context.empty?
    end

    def clear_context
      @context = []
    end

    def push_context(val)
      @context.push(val)
    end

    def pop_context
      @context.pop
    end

    def current_context
      @context.last
    end

    def push_path(val)
      @current_path.push(val)
    end

    def pop_path
      @current_path.pop
    end

    def parse_scalar(value)
      @scalar_scanner.tokenize(value)
    rescue ArgumentError, Psych::SyntaxError
      value.to_s
    end

    def validate_node(node)
      value = parse_scalar(node.value)

      rule_set = @ruleset.lookup(@current_path)

      if rule_set.nil?
        @errors << Argot::Annotation.new(path: @file_name,
          location: @current_location.dup,
          level: Annotation::WARNING,
          title: "Invalid Key",
          message: "'#{@current_path.join(".")}' is not permitted in this document.")
        return
      end

      return unless rule_set[:value].any?

      validation_errors = []
      valid = false

      rule_set[:value].each do |tag|
        validation_errors.append(tag.expectation)
        valid = true if tag.validate(value)
      end

      return if valid

      expectations = (validation_errors.size > 1) ? "#{validation_errors[0..-2].join(", ")}, or #{validation_errors[-1]}" : validation_errors.first

      @errors << Argot::Annotation.new(path: @file_name,
        location: @current_location.dup,
        level: Annotation::FAILURE,
        title: "Invalid Value",
        message: "The value '#{value}' is invalid for #{@current_path.join(".")}",
        details: "Expected #{expectations}")
    end

    def encountered_path?(subkey_path)
      return true if subkey_path.empty?

      @encountered_paths.keys.any? do |tracked_path|
        @ruleset.match_path?(subkey_path, tracked_path)
      end
    end

    def emit_missing_key_error(subkey_path)
      return if @missing_keys.key?(subkey_path)

      @errors << Argot::Annotation.new(
        path: @file_name,
        location: @encountered_paths[subkey_path] || @encountered_paths[subkey_path[..subkey_path.length - 2]] || {},
        level: Argot::Annotation::FAILURE,
        title: "Missing Key",
        message: "The key '#{subkey_path.join(".")}' is required, but missing."
      )

      @missing_keys[subkey_path] = nil
    end
  end
end

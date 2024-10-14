# frozen_string_literal: true

require "psych"
require_relative "argot/version"
require_relative "argot/location"
require_relative "argot/annotation"
require_relative "argot/tag"
require_relative "argot/validator"
require_relative "argot/schema"

module Argot
  class Error < StandardError; end

  class Unprocessable < Error; end

  class MaliciousInput < Unprocessable; end

  def self.load(schema_yaml, document_yaml, uri: nil)
    schema = Argot::Schema::Parser.parse(schema_yaml)
    document = Argot::Schema::Parser.parse(document_yaml)

    Argot::Validator.new(schema.tree, document.tree)
  end
end

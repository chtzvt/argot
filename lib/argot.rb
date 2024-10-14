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
end

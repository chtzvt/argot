module Argot
  class Location
    attr_accessor :start_line, :end_line, :start_column, :end_column

    def initialize(start_line: nil, end_line: nil, start_column: nil, end_column: nil)
      @start_line = start_line || 1
      @end_line = end_line || start_line || 1
      @start_column = start_column || 1
      @end_column = end_column || start_column || 1
    end
  end
end

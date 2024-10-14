module Argot
  class Annotation
    NOTICE = :notice
    WARNING = :warning
    FAILURE = :failure

    attr_reader :start_line, :end_line, :start_column, :end_column, :level, :message, :title, :details
    attr_accessor :path

    def initialize(path: nil, location: nil, level: nil, message: nil, title: nil, details: nil)
      @path = path || "input"

      self.location = if location.is_a? Argot::Location
        location
      else
        Argot::Location.new(**location)
      end

      @level = level || NOTICE
      @message = message
      @title = title || message
      @details = details || message
    end

    def location=(location)
      @start_line = location.start_line
      @end_line = location.end_line
      @start_column = location.start_column
      @end_column = location.end_column
    end

    def to_h
      {
        path: @path,
        start_line: @start_line,
        end_line: @end_line,
        start_column: @start_column,
        end_column: @end_column,
        annotation_level: @level,
        message: @message,
        title: @title,
        raw_details: @details
      }
    end

    def to_s
      msg = "[#{@level.to_s.upcase}] At lines:#{@start_line}-#{@end_line} cols:#{@start_column}-#{@end_column} of #{@path} -- #{@title}: #{@message}"
      msg += " (#{@details})" unless @details == @message
      msg
    end
  end
end

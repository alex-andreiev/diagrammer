# frozen_string_literal: true

require 'fileutils'

module Diagrammer
  class Generator
    def initialize(output:, models: nil, introspector: ModelIntrospector.new(models: models))
      @output = output
      @introspector = introspector
    end

    def call
      diagram = @introspector.call
      html = HtmlRenderer.new(
        diagram: diagram,
        title: 'Database Diagram',
        notice: notice_for(diagram)
      ).call

      write(html)
      @output.to_s
    end

    private

    # The rake task defaults to Rails.root, but an explicit path may point into
    # a directory that does not exist yet (tmp/, doc/, a CI artifact dir).
    def write(html)
      path = @output.to_s
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, html)
    end

    def notice_for(diagram)
      return unless diagram.fetch(:tables).empty?

      'No database tables were found. Check that the Rails database exists, migrations are run, and models can load.'
    end
  end
end

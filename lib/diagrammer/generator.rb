# frozen_string_literal: true

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

      File.write(@output, html)
      @output.to_s
    end

    private

    def notice_for(diagram)
      return unless diagram.fetch(:tables).empty?

      'No database tables were found. Check that the Rails database exists, migrations are run, and models can load.'
    end
  end
end

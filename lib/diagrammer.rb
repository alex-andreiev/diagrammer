# frozen_string_literal: true

require_relative 'diagrammer/version'
require_relative 'diagrammer/model_introspector'
require_relative 'diagrammer/html_renderer'
require_relative 'diagrammer/generator'
require_relative 'diagrammer/railtie' if defined?(Rails::Railtie)

module Diagrammer
  class Error < StandardError; end

  def self.generate(output:, models: nil)
    Generator.new(output: output, models: models).call
  end
end

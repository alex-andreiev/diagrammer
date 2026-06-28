# frozen_string_literal: true

require 'rails/railtie'

module Diagrammer
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path('tasks/diagrammer.rake', __dir__)
    end
  end
end

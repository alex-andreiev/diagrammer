# frozen_string_literal: true

require_relative 'lib/diagrammer/version'

Gem::Specification.new do |spec|
  spec.name = 'diagrammer'
  spec.version = Diagrammer::VERSION
  spec.authors = ['Alex']
  spec.email = ['alex@example.com']

  spec.summary = 'Generate Rails database relationship diagrams as standalone HTML.'
  spec.description = 'Diagrammer introspects ActiveRecord models and renders an interactive, '
  spec.description += 'fully offline ER diagram as a standalone HTML file, without Graphviz.'
  spec.homepage = 'https://example.com/diagrammer'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['lib/**/*', 'README.md', 'LICENSE.txt']
  end

  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 6.1'
  spec.add_dependency 'railties', '>= 6.1'

  spec.add_development_dependency 'rake', '>= 13.0'
  spec.add_development_dependency 'rspec', '>= 3.0'
  spec.add_development_dependency 'rubocop', '>= 1.75'
end

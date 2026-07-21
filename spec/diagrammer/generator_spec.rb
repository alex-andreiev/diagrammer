# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe Diagrammer::Generator do
  let(:introspector) { instance_double(Diagrammer::ModelIntrospector, call: diagram) }
  let(:diagram) { { tables: [], relationships: [] } }

  it 'writes the diagram and returns the path' do
    Dir.mktmpdir do |dir|
      output = File.join(dir, 'dbdiagram.html')

      result = described_class.new(output: output, introspector: introspector).call

      expect(result).to eq(output)
      expect(File.read(output)).to include('<!doctype html>')
    end
  end

  it 'creates missing parent directories for the output path' do
    Dir.mktmpdir do |dir|
      output = File.join(dir, 'nested', 'deeper', 'dbdiagram.html')

      expect { described_class.new(output: output, introspector: introspector).call }.not_to raise_error
      expect(File).to exist(output)
    end
  end

  it 'accepts a Pathname output, as the rake task passes Rails.root.join' do
    Dir.mktmpdir do |dir|
      output = Pathname.new(dir).join('sub', 'dbdiagram.html')

      result = described_class.new(output: output, introspector: introspector).call

      expect(result).to eq(output.to_s)
      expect(File).to exist(output)
    end
  end

  it 'notices an empty schema' do
    Dir.mktmpdir do |dir|
      output = File.join(dir, 'dbdiagram.html')

      described_class.new(output: output, introspector: introspector).call

      expect(File.read(output)).to include('No database tables were found')
    end
  end
end

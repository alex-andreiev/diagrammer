# frozen_string_literal: true

require 'spec_helper'

FakeColumn = Struct.new(:name, :type)

# Minimal stand-in for an ActiveRecord model class.
class FakeModel
  attr_reader :name, :table_name, :primary_key, :columns

  def initialize(name:, table_name:, columns: [], associations: [])
    @name = name
    @table_name = table_name
    @primary_key = 'id'
    @columns = columns
    @associations = associations
  end

  def abstract_class? = false
  def table_exists? = true
  def reflect_on_all_associations = @associations
end

RSpec.describe Diagrammer::ModelIntrospector do
  def model(name, table_name)
    FakeModel.new(
      name: name,
      table_name: table_name,
      columns: [FakeColumn.new('id', 'integer')]
    )
  end

  it 'emits one table per table_name when several models share it (STI)' do
    models = [
      model('Step', 'steps'),
      model('Steps::OpenEnded', 'steps'),
      model('Steps::MultipleChoice', 'steps'),
      model('User', 'users')
    ]

    diagram = described_class.new(models: models).call
    table_names = diagram[:tables].map { |t| t[:table_name] }

    expect(table_names).to eq(%w[steps users])
  end

  it 'keeps distinct tables' do
    models = [model('User', 'users'), model('Post', 'posts')]

    diagram = described_class.new(models: models).call

    expect(diagram[:tables].size).to eq(2)
  end
end

# frozen_string_literal: true

require 'spec_helper'

FakeColumn = Struct.new(:name, :type)

# Minimal stand-in for an ActiveRecord reflection.
class FakeAssociation
  attr_reader :macro, :name, :klass, :foreign_key, :join_table

  def initialize(macro:, name:, klass:, foreign_key: nil, join_table: nil, through: false)
    @macro = macro
    @name = name
    @klass = klass
    @foreign_key = foreign_key || "#{name}_id"
    @join_table = join_table
    @through = through
  end

  def through_reflection? = @through
end

# Minimal stand-in for an ActiveRecord model class.
class FakeModel
  attr_reader :name, :table_name, :primary_key, :columns
  attr_accessor :associations

  def initialize(name:, table_name:, columns: [], associations: [], base_class: nil)
    @name = name
    @table_name = table_name
    @primary_key = 'id'
    @columns = columns
    @associations = associations
    @base_class = base_class
  end

  def base_class = @base_class || self
  def abstract_class? = false
  def table_exists? = true
  def reflect_on_all_associations = @associations
end

RSpec.describe Diagrammer::ModelIntrospector do
  def model(name, table_name, associations: [], base_class: nil)
    FakeModel.new(
      name: name,
      table_name: table_name,
      columns: [FakeColumn.new('id', 'integer')],
      associations: associations,
      base_class: base_class
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

  describe 'model selection' do
    it 'labels an STI table with the base class, not the alphabetically first subclass' do
      base = model('User', 'users')
      admin = model('AdminUser', 'users', base_class: base)

      diagram = described_class.new(models: [admin, base]).call

      expect(diagram[:tables].map { |t| t[:model_name] }).to eq(['User'])
    end

    it 'does not crash on anonymous model classes' do
      anonymous = model(nil, 'users')
      named = model('User', 'users')

      diagram = described_class.new(models: [anonymous, named]).call

      expect(diagram[:tables].map { |t| t[:model_name] }).to eq(['User'])
    end

    it 'still emits a table when only an anonymous model backs it' do
      diagram = described_class.new(models: [model(nil, 'users')]).call

      expect(diagram[:tables].map { |t| t[:table_name] }).to eq(['users'])
    end
  end

  describe 'eager loading' do
    it 'skips eager loading when Rails is defined without an application' do
      stub_const('Rails', double(application: nil))

      expect { described_class.new(models: []).call }.not_to raise_error
    end
  end

  describe 'relationships' do
    it 'collapses a belongs_to and its inverse has_many into one edge' do
      users = model('User', 'users')
      posts = model('Post', 'posts')
      posts.associations = [FakeAssociation.new(macro: :belongs_to, name: 'user', klass: users)]
      users.associations = [
        FakeAssociation.new(macro: :has_many, name: 'posts', klass: posts, foreign_key: 'user_id')
      ]

      diagram = described_class.new(models: [users, posts]).call

      expect(diagram[:relationships]).to eq(
        [{ from: 'posts', to: 'users', name: 'user', macro: :has_many, foreign_key: 'user_id' }]
      )
    end

    it 'keeps two edges when two associations use different foreign keys' do
      users = model('User', 'users')
      posts = model('Post', 'posts')
      posts.associations = [
        FakeAssociation.new(macro: :belongs_to, name: 'user', klass: users),
        FakeAssociation.new(macro: :belongs_to, name: 'editor', klass: users, foreign_key: 'editor_id')
      ]

      diagram = described_class.new(models: [users, posts]).call

      expect(diagram[:relationships].map { |r| r[:foreign_key] }).to contain_exactly('user_id', 'editor_id')
    end

    it 'collapses both sides of a has_and_belongs_to_many into one edge' do
      albums = model('Album', 'albums')
      photos = model('Photo', 'photos')
      albums.associations = [
        FakeAssociation.new(macro: :has_and_belongs_to_many, name: 'photos', klass: photos,
                            foreign_key: 'album_id', join_table: 'albums_photos')
      ]
      photos.associations = [
        FakeAssociation.new(macro: :has_and_belongs_to_many, name: 'albums', klass: albums,
                            foreign_key: 'photo_id', join_table: 'albums_photos')
      ]

      diagram = described_class.new(models: [albums, photos]).call

      expect(diagram[:relationships].size).to eq(1)
      expect(diagram[:relationships].first[:macro]).to eq(:has_and_belongs_to_many)
    end

    it 'reports a has_one pair as one-to-one' do
      users = model('User', 'users')
      profiles = model('Profile', 'profiles')
      users.associations = [
        FakeAssociation.new(macro: :has_one, name: 'profile', klass: profiles, foreign_key: 'user_id')
      ]
      profiles.associations = [FakeAssociation.new(macro: :belongs_to, name: 'user', klass: users)]

      diagram = described_class.new(models: [users, profiles]).call

      expect(diagram[:relationships].size).to eq(1)
      expect(diagram[:relationships].first).to include(from: 'profiles', to: 'users', macro: :has_one)
    end

    it 'ignores has_many :through, which has no foreign key of its own' do
      users = model('User', 'users')
      comments = model('Comment', 'comments')
      users.associations = [
        FakeAssociation.new(macro: :has_many, name: 'comments', klass: comments,
                            foreign_key: 'post_id', through: true)
      ]

      diagram = described_class.new(models: [users, comments]).call

      expect(diagram[:relationships]).to be_empty
    end
  end
end

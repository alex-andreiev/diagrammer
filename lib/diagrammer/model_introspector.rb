# frozen_string_literal: true

require 'set'

module Diagrammer
  class ModelIntrospector
    ASSOCIATION_MACROS = %i[belongs_to has_one has_many has_and_belongs_to_many].freeze

    def initialize(models: nil)
      @models = models
    end

    def call
      eager_load_rails_application

      models = selected_models.sort_by(&:name)
      {
        tables: unique_tables(models),
        relationships: relationships_for(models)
      }
    end

    private

    # Several models can share one database table (STI subclasses, gem base
    # classes such as I18n's Translation, multi-schema rpush models). Emit a
    # single card per table; associations from every model still merge onto it
    # via relationships_for, which is keyed by table name.
    def unique_tables(models)
      models.each_with_object({}) do |model, by_table|
        by_table[model.table_name] ||= table_for(model)
      end.values
    end

    def eager_load_rails_application
      return unless defined?(Rails) && Rails.respond_to?(:application)

      Rails.application.eager_load!
    end

    def selected_models
      models = @models || active_record_models
      models.select { |model| concrete_model?(model) }
    end

    def active_record_models
      return [] unless defined?(ActiveRecord::Base)

      ActiveRecord::Base.descendants
    end

    def concrete_model?(model)
      model.respond_to?(:table_name) &&
        model.respond_to?(:columns) &&
        !model.abstract_class? &&
        model.table_exists?
    rescue StandardError
      false
    end

    def table_for(model)
      {
        model_name: model.name,
        table_name: model.table_name,
        columns: columns_for(model)
      }
    end

    def columns_for(model)
      primary_key = model.primary_key.to_s

      model.columns.map do |column|
        {
          name: column.name,
          type: column.type.to_s,
          primary_key: column.name == primary_key,
          foreign_key: column.name.end_with?('_id')
        }
      end
    end

    def relationships_for(models)
      table_names = models.to_set(&:table_name)
      models.flat_map { |model| model_relationships(model, table_names) }.uniq
    end

    def model_relationships(model, table_names)
      model.reflect_on_all_associations.filter_map do |association|
        relationship_for(model, association, table_names)
      end
    end

    def relationship_for(model, association, table_names)
      return unless ASSOCIATION_MACROS.include?(association.macro)

      target_table = association_table_name(association)
      return unless target_table && table_names.include?(target_table)

      {
        from: model.table_name,
        to: target_table,
        name: association.name.to_s,
        macro: association.macro
      }
    end

    def association_table_name(association)
      association.klass.table_name
    rescue StandardError
      nil
    end
  end
end

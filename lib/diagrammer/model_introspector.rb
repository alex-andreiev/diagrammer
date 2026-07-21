# frozen_string_literal: true

module Diagrammer
  class ModelIntrospector
    def initialize(models: nil)
      @models = models
    end

    def call
      eager_load_rails_application

      models = selected_models.sort_by { |model| model.name.to_s }
      {
        tables: unique_tables(models),
        relationships: RelationshipMapper.new(models: models).call
      }
    end

    private

    # Several models can share one database table (STI subclasses, gem base
    # classes such as I18n's Translation, multi-schema rpush models). Emit a
    # single card per table; associations from every model still merge onto it
    # via RelationshipMapper, which is keyed by table name.
    def unique_tables(models)
      models.group_by(&:table_name).map { |_table, group| table_for(preferred_model(group)) }
    end

    # Models are sorted by name, so an STI subclass can win the card label over
    # its own base class ("AdminUser" < "User"). Prefer the root of the
    # hierarchy, and never let an anonymous class name a table it shares.
    def preferred_model(group)
      named = group.reject { |model| model.name.to_s.empty? }
      candidates = named.empty? ? group : named
      candidates.find { |model| sti_base?(model) } || candidates.first
    end

    def sti_base?(model)
      model.respond_to?(:base_class) && model.base_class == model
    rescue StandardError
      false
    end

    # Rails.respond_to?(:application) is true even before an application is
    # defined (engines, gem test suites), where the reader returns nil.
    def eager_load_rails_application
      return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

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
  end
end

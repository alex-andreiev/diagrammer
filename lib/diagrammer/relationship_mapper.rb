# frozen_string_literal: true

require 'set'

module Diagrammer
  # Turns ActiveRecord reflections into the table-to-table edges the renderer
  # draws. Every edge is oriented from the table holding the foreign key to the
  # table it references, so the renderer can anchor the line on the FK column.
  class RelationshipMapper
    ASSOCIATION_MACROS = %i[belongs_to has_one has_many has_and_belongs_to_many].freeze

    # Ordered weakest-to-strongest. When a belongs_to and its inverse collapse
    # onto one edge, the strongest macro in the group decides the cardinality.
    MACRO_STRENGTH = %i[belongs_to has_one has_many has_and_belongs_to_many].freeze

    def initialize(models:)
      @models = models
      @table_names = models.to_set(&:table_name)
    end

    def call
      candidates = @models.flat_map { |model| model_relationships(model) }
      merge_reciprocals(candidates)
    end

    private

    def model_relationships(model)
      model.reflect_on_all_associations.filter_map do |association|
        relationship_for(model, association)
      end
    end

    # A belongs_to and its inverse has_many/has_one describe the *same* physical
    # foreign key. Emitting both draws two connectors between the same pair of
    # cards, with contradicting crow's feet, so collapse them onto one edge.
    def merge_reciprocals(candidates)
      candidates.group_by { |relationship| relationship[:key] }.map do |_key, group|
        representative(group)
          .merge(macro: strongest_macro(group))
          .except(:key)
      end
    end

    # The belongs_to side names the association after the foreign key, which
    # makes the better edge label; fall back to whichever side we have.
    def representative(group)
      group.find { |relationship| relationship[:macro] == :belongs_to } || group.first
    end

    def strongest_macro(group)
      group.map { |relationship| relationship[:macro] }
           .max_by { |macro| MACRO_STRENGTH.index(macro) || -1 }
    end

    def relationship_for(model, association)
      return unless ASSOCIATION_MACROS.include?(association.macro)
      # A has_many :through has no foreign key of its own; the underlying
      # associations already draw every physical link along the path.
      return if through_association?(association)

      target_table = association_table_name(association)
      return unless target_table && @table_names.include?(target_table)

      if association.macro == :has_and_belongs_to_many
        habtm_relationship(model, association, target_table)
      else
        directed_relationship(model, association, target_table)
      end
    end

    def directed_relationship(model, association, target_table)
      foreign_key = association_foreign_key(association)
      child, parent = endpoints(model, association, target_table)

      {
        key: [child, parent, foreign_key],
        from: child, to: parent,
        name: association.name.to_s,
        macro: association.macro,
        foreign_key: foreign_key
      }
    end

    # Only belongs_to declares the foreign key on its own table; has_many and
    # has_one point at a key living on the far side.
    def endpoints(model, association, target_table)
      if association.macro == :belongs_to
        [model.table_name, target_table]
      else
        [target_table, model.table_name]
      end
    end

    # Both sides of a habtm share one join table, which is what identifies the
    # edge; the endpoints are sorted so either side produces the same key.
    def habtm_relationship(model, association, target_table)
      from, to = [model.table_name, target_table].sort

      {
        key: [:habtm, association_join_table(association), from, to],
        from: from, to: to,
        name: association.name.to_s,
        macro: association.macro,
        foreign_key: nil
      }
    end

    def through_association?(association)
      association.respond_to?(:through_reflection?) && association.through_reflection?
    rescue StandardError
      false
    end

    def association_table_name(association)
      association.klass.table_name
    rescue StandardError
      nil
    end

    def association_foreign_key(association)
      association.foreign_key.to_s
    rescue StandardError
      nil
    end

    def association_join_table(association)
      association.join_table.to_s
    rescue StandardError
      nil
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe Diagrammer::HtmlRenderer do
  let(:diagram) do
    {
      tables: [
        {
          model_name: 'User',
          table_name: 'users',
          columns: [
            { name: 'id', type: 'integer', primary_key: true, foreign_key: false },
            { name: 'team_id', type: 'integer', primary_key: false, foreign_key: true }
          ]
        }
      ],
      relationships: [
        { from: 'users', to: 'teams', name: 'team', macro: :belongs_to }
      ]
    }
  end

  def render(diagram_data, **options)
    described_class.new(diagram: diagram_data, title: 'Database Diagram', **options).call
  end

  it 'embeds the diagram as JSON' do
    html = render(diagram)

    payload = html[%r{<script id="diagram-data" type="application/json">(.*?)</script>}m, 1]
    expect(payload).not_to be_nil

    parsed = JSON.parse(payload)
    expect(parsed.dig('tables', 0, 'table_name')).to eq('users')
    expect(parsed.dig('tables', 0, 'columns', 1, 'name')).to eq('team_id')
    expect(parsed.dig('tables', 0, 'columns', 1, 'foreign_key')).to be(true)
    expect(parsed.dig('relationships', 0, 'to')).to eq('teams')
  end

  it 'neutralizes script injection in the embedded data' do
    nasty = {
      tables: [{ model_name: 'X', table_name: '</script><script>alert(1)</script>', columns: [] }],
      relationships: []
    }
    html = render(nasty)

    expect(html).not_to include('</script><script>alert(1)')
    expect(html).to include('<\/script>')
  end

  it 'is offline and free of Mermaid' do
    html = render(diagram)

    expect(html).not_to include('mermaid')
    expect(html).not_to include('cdn.jsdelivr.net')
  end

  it 'includes the viewer controls' do
    html = render(diagram)

    expect(html).to include('data-action="relayout"')
    expect(html).to include('data-action="fit"')
    expect(html).to include('class="viewport"')
  end

  it 'renders a notice when present' do
    html = render({ tables: [], relationships: [] }, notice: 'No tables found')

    expect(html).to include('No tables found')
    expect(html).to include('class="notice"')
  end
end

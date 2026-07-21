# Diagrammer

Diagrammer is a Rails gem that generates a standalone, interactive database relationship diagram from ActiveRecord models.

![Diagrammer example output](https://raw.githubusercontent.com/alex-andreiev/diagrammer/main/docs/screenshot.png)

It introspects your Rails application, reads model columns and associations, and writes a single browser-friendly HTML file. The diagram renders as draggable table cards — similar in spirit to dbdiagram.io — directly in the browser. The main design goal is a zero-dependency workflow: no Graphviz, no system packages, no local diagram renderer, no PDF toolchain, and no network access required to view the result.

## Problem It Solves

In many Rails applications, the actual domain model becomes hard to understand from migrations, schema files, and model files alone. Developers often need to answer practical questions before making a safe change:

- Which models exist in the application?
- Which tables are connected?
- Which columns are primary keys and foreign keys?
- What does this part of the data model look like before a refactor?
- How can a team share a schema overview without installing Graphviz or using an external SaaS?

Diagrammer solves this by generating a visual relationship map directly from the Rails app. It uses ActiveRecord models as the source of truth and produces a standalone HTML file that can be opened in a browser, committed to documentation, shared in pull requests, or used during onboarding.

## Why This Gem Exists

Rails projects often accumulate relationships faster than the schema stays understandable. Existing tools can work well, but they commonly require Graphviz, generate static image files, depend on an external service, or need extra setup that makes them inconvenient in Docker, CI, or onboarding workflows.

Diagrammer takes a simpler approach:

- Use Rails and ActiveRecord reflection as the source of truth.
- Generate a portable HTML file that can be opened in any browser.
- Render in the browser with a small inline script — no Graphviz, no CDN, no external service.
- Keep the output easy to understand and extend.

## The Diagram

The generated page renders each table as a card and draws relationships between them:

- **Table cards** with a colored header (table name) and one row per column.
- **Column details**: name, ActiveRecord type, and `PK` / `FK` badges.
- **Relationship lines** drawn as smooth curves. A line attaches to the foreign-key
  column row when it can be inferred (an association named `team` anchors at
  `team_id`); otherwise it attaches to the card edge.
- **Automatic layout** via a built-in force-directed simulation with collision
  avoidance, so cards do not overlap on first render.

It is interactive:

- **Scroll** to zoom toward the cursor.
- **Drag the background** to pan.
- **Drag a table** to move it; dragging dims unrelated tables to highlight its neighbors.
- **Re-layout** re-runs the automatic layout, **Fit** frames the whole diagram, and **Reset view** restores the default zoom.

The full diagram spans the page width and is read-only.

## Current Status

This project is an MVP. It is usable for small and medium Rails apps, but the API and output format may still change before a `1.0.0` release.

Currently supported:

- Rails rake task: `diagrammer:generate`
- Programmatic Ruby API: `Diagrammer.generate(...)`
- ActiveRecord model discovery through `ActiveRecord::Base.descendants`
- Rails eager loading before introspection
- Column rendering with type names
- Primary key marker: `PK`
- Foreign key marker for columns ending in `_id`: `FK`
- Association rendering for `belongs_to`, `has_one`, `has_many`, and `has_and_belongs_to_many`
- Standalone, fully offline HTML output (no CDN, no network access)

Not implemented yet:

- Mounted Rails engine dashboard
- JSON export as a public API
- Model/table filtering options
- Polymorphic association visualization details
- STI-specific grouping
- Saved manual layout positions
- Direct PNG/SVG/PDF export

## Requirements

- Ruby `>= 3.1`
- Rails / Railties `>= 6.1`
- ActiveRecord `>= 6.1`
- Any modern browser to open the generated HTML file

The generated file is self-contained: all CSS and JavaScript are inlined and the
table data is embedded as JSON. It needs no internet access to render, so it works
in air-gapped environments, Docker, and offline machines.

## Installation

For local development while this gem is not published yet, add it to a Rails application's `Gemfile` with a path:

```ruby
gem 'diagrammer', path: '../diagrammer'
```

Then install dependencies:

```bash
bundle install
```

After the gem is published, the installation will become:

```ruby
gem 'diagrammer', group: :development
```

Recommended usage is development-only. The gem introspects your application models and is intended as a developer tool, not a production runtime dependency.

## How To Use

The normal workflow is:

1. Add the gem to a Rails application.
2. Run the generator task from the Rails app.
3. Open the generated HTML file in a browser.
4. Share or commit the file if the diagram should become part of the project documentation.

Generate `dbdiagram.html` in the Rails project root:

```bash
bin/rails diagrammer:generate
```

Open the generated file in a browser on macOS:

```bash
open dbdiagram.html
```

Open the generated file in a browser on Linux:

```bash
xdg-open dbdiagram.html
```

Generate to a custom path, for example inside a documentation directory:

```bash
bin/rails 'diagrammer:generate[docs/dbdiagram.html]'
```

The quotes around the task are recommended because some shells treat square brackets specially.

A typical documentation flow is:

```bash
mkdir -p docs
bin/rails 'diagrammer:generate[docs/dbdiagram.html]'
git add docs/dbdiagram.html
```

## Programmatic Usage

You can generate a diagram from Ruby code:

```ruby
Diagrammer.generate(output: Rails.root.join('dbdiagram.html'))
```

You can also pass a specific list of models. This is useful for tests, engines, or focused diagrams:

```ruby
Diagrammer.generate(
  output: Rails.root.join('billing_diagram.html'),
  models: [Account, Invoice, Payment]
)
```

The method returns the output path as a string:

```ruby
path = Diagrammer.generate(output: Rails.root.join('dbdiagram.html'))
puts path
```

## What Gets Rendered

Each ActiveRecord model becomes a table card based on its database table name.

For every model, Diagrammer renders:

- Table name (card header)
- Columns
- Column ActiveRecord type, such as `integer`, `string`, `datetime`, `boolean`
- Primary key marker (`PK`), based on `model.primary_key`
- Foreign key marker (`FK`), based on the `_id` column suffix

Associations become relationship lines between cards. A model like this:

```ruby
class User < ApplicationRecord
  belongs_to :account
  has_many :orders
end
```

produces a line from `users` to `accounts` (anchored at the `account_id` row when
present) and a line from `users` to `orders`.

## Association Handling

Diagrammer discovers associations for these macros:

| ActiveRecord macro | Meaning |
| --- | --- |
| `belongs_to` | Source record references one target record |
| `has_one` | Source record has zero or one target record |
| `has_many` | Source record has zero or many target records |
| `has_and_belongs_to_many` | Many-to-many relationship |

An association is included only if its target table also belongs to the selected
model set, which prevents external or unresolved associations from creating broken
links. Relationship direction and optionality are not currently derived from
validations or database constraints, so the diagram shows connectivity rather than
exact cardinality.

## How Model Discovery Works

The generator calls Rails eager loading before introspection:

```ruby
Rails.application.eager_load!
```

Then it reads models from:

```ruby
ActiveRecord::Base.descendants
```

A model is included only if it appears to be a concrete table-backed model:

- It responds to `table_name`.
- It responds to `columns`.
- It is not an abstract class.
- `table_exists?` returns true.

Associations are discovered through:

```ruby
model.reflect_on_all_associations
```

## Output

By default the rake task writes:

```text
dbdiagram.html
```

The HTML file contains:

- A responsive, full-width page layout
- The introspected schema embedded as JSON in a `<script type="application/json">` block
- An inline stylesheet and an inline renderer script that builds the cards, lays
  them out, draws the relationship lines, and wires up zoom / pan / drag

The file is self-contained and portable. It is meant to be committed to docs,
attached to tickets, shared during onboarding, or generated temporarily during
development.

## Development

Install dependencies:

```bash
bundle install
```

Run the specs:

```bash
bundle exec rake spec
```

Run RuboCop:

```bash
bundle exec rubocop
```

Run the default task, which includes tests and linting:

```bash
bundle exec rake
```

## Continuous Integration

The repository includes a GitHub Actions workflow in `.github/workflows/ci.yml`.

CI runs on:

- Pushes to `main`
- Pull requests

The workflow checks:

- Ruby `3.1`
- Ruby `3.4`
- `bundle exec rake spec`
- `bundle exec rubocop`

## Project Structure

```text
lib/diagrammer.rb
lib/diagrammer/generator.rb
lib/diagrammer/html_renderer.rb
lib/diagrammer/model_introspector.rb
lib/diagrammer/railtie.rb
lib/diagrammer/tasks/diagrammer.rake
spec/
```

Key files:

- `Diagrammer::ModelIntrospector` collects models, columns, and associations
  into a plain Ruby hash.
- `Diagrammer::HtmlRenderer` embeds that data as JSON in a standalone HTML page
  and ships the inline card renderer.
- `Diagrammer::Generator` coordinates introspection, rendering, and file writing.
- `Diagrammer::Railtie` loads the Rails rake task.

## Known Limitations

The current implementation keeps the model simple. Be aware of these limitations:

- Foreign keys are detected by column name suffix only: `_id`.
- Database foreign key constraints are not inspected yet.
- Polymorphic associations may be skipped if `association.klass` cannot be resolved.
- STI models may produce output that needs refinement.
- Association optionality is not read from validations or database null constraints.
- Relationship lines anchor to a foreign-key row only when it can be inferred from
  the association name; otherwise they attach to the card edge.
- Automatic layout is not persisted between regenerations.
- Very large schemas (hundreds of tables) produce a large canvas; use zoom, pan,
  and drag to navigate.

## Roadmap

Near-term improvements:

- Add filtering options for selected models and ignored tables.
- Add JSON output as a public API for richer interactive frontends.
- Improve polymorphic association handling.
- Add database foreign key constraint introspection.
- Add configurable output title and color themes.
- Make eager loading resilient to misconfigured host applications.

Larger features:

- Mountable Rails engine at `/diagrammer` for live diagrams in development.
- Search, hide/show, and relationship highlighting in the viewer.
- Persisted layout positions per project.
- Export to SVG/PNG through browser-side rendering.

## Design Principles

- No Graphviz dependency.
- No network dependency: the generated file renders offline.
- Prefer Rails reflection over parsing source files.
- Keep generated output easy to inspect and debug.
- Avoid production runtime assumptions.
- Make the MVP useful before adding a heavy frontend.

## Contributing

Before opening a pull request, run:

```bash
bundle exec rake
```

When changing model introspection behavior, add specs around the generated
intermediate data.

When changing HTML output, keep the generated file portable and offline, and avoid
adding build steps unless there is a clear reason.

## License

The gem is available as open source under the terms of the MIT License.

# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-07-21

### Fixed

- Do not crash on anonymous ActiveRecord classes. Sorting models by `name`
  raised `ArgumentError: comparison of NilClass with String failed` when any
  `Class.new(ActiveRecord::Base)` was loaded in the process.
- Do not crash when `Rails` is loaded without an application (engines, gem test
  suites). The eager-load guard checked `Rails.respond_to?(:application)`, which
  is true even while `Rails.application` is still `nil`.
- Draw one connector per relationship instead of two. A `belongs_to` and its
  inverse `has_many`/`has_one` describe the same foreign key, and both were
  emitted, producing duplicate lines with contradicting crow's feet. On a
  17-table application this halved the edge count from 36 to 18.
- Label a shared table with its STI base class rather than whichever subclass
  sorted first alphabetically (`AdminUser` no longer names the `users` card),
  and never let an anonymous class name a table it shares.
- Anchor connectors on the real foreign key column instead of guessing
  `"#{association_name}_id"`, which missed every association declared with a
  custom `:foreign_key`.
- Create missing parent directories for the output path, so writing to a nested
  path such as `tmp/diagrams/erd.html` no longer raises `Errno::ENOENT`.
- Keep graph traversal correct for tables and columns whose names collide with
  `Object.prototype` members (`constructor`, `__proto__`), which previously
  stranded such a card at the origin, unlaid-out and overlapping its neighbours.

### Changed

- Relationships are now oriented from the table holding the foreign key to the
  table it references, and carry a `foreign_key` field. `has_many :through` is
  no longer emitted, since it has no foreign key of its own and the underlying
  associations already draw every physical link along the path.
- Relationship mapping moved into `Diagrammer::RelationshipMapper`.
- The README screenshot uses an absolute URL so it renders outside the
  repository, where the previous relative path resolved to nothing.

## [0.1.0] - 2026-06-28

### Added

- Initial release.
- `diagrammer:generate` rake task and `Diagrammer.generate` Ruby API.
- ActiveRecord introspection of models, columns, and associations, with tables
  deduplicated across models that share one table (STI, gem base classes,
  multi-schema setups).
- Standalone, fully offline HTML output: draggable dbdiagram.io-style table cards
  with `PK`/`FK` badges, orthogonal crow's-foot relationship connectors, a
  cluster-based layout that fills the viewport width, and zoom/pan/drag — no
  Graphviz, no CDN, no network access required.

[Unreleased]: https://github.com/alex-andreiev/diagrammer/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/alex-andreiev/diagrammer/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/alex-andreiev/diagrammer/releases/tag/v0.1.0

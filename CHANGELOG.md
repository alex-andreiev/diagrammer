# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/alex-andreiev/diagrammer/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alex-andreiev/diagrammer/releases/tag/v0.1.0

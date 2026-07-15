# Architecture Image Exports

This folder contains generated diagram images exported from
`../diagrams/ARCHITECTURE.puml` or from the Astah project kept under
`../diagrams/astah/`.

Refresh PlantUML PNG exports from the repository root with:

```sh
plantuml -tpng -o ../architecture docs/diagrams/ARCHITECTURE.puml
```

SVG exports can use the same destination when needed:

```sh
plantuml -tsvg -o ../architecture docs/diagrams/ARCHITECTURE.puml
```

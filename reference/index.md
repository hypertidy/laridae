# Package index

## Create and edit a mesh

A persistent handle: build it, then insert or remove points and
constraint segments in place (vertex ids stay stable).

- [`lari_new()`](https://hypertidy.github.io/laridae/reference/lari_new.md)
  : Create a mesh handle
- [`lari_add_points()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md)
  [`lari_add_segments()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md)
  [`lari_remove_points()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md)
  [`lari_remove_segments()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md)
  : Edit a mesh

## Refine

Delaunay refinement, step-by-step refinement, and the edge-length floor.

- [`lari_refine()`](https://hypertidy.github.io/laridae/reference/lari_refine.md)
  : Refine a mesh
- [`lari_step()`](https://hypertidy.github.io/laridae/reference/lari_step.md)
  : Step the mesher
- [`default_min_edge_length()`](https://hypertidy.github.io/laridae/reference/default_min_edge_length.md)
  : Default refinement edge-length floor

## Output and inspection

The vertices / segments / triangles contract, mesh counts, and the
one-row provenance report.

- [`lari_tables()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)
  [`lari_vertices()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)
  [`lari_triangles()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)
  [`lari_segments()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)
  [`lari_depth()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)
  : Mesh tables
- [`lari_counts()`](https://hypertidy.github.io/laridae/reference/lari_counts.md)
  : Mesh counts

## One-shot

Build and optionally refine in a single call.

- [`lari_triangulate()`](https://hypertidy.github.io/laridae/reference/lari_triangulate.md)
  : One-shot constrained triangulation

## Text

Glyph outlines from installed fonts, meshed as polygons with holes.

- [`lari_text()`](https://hypertidy.github.io/laridae/reference/lari_text.md)
  : Meshed text
- [`lari_text_outline()`](https://hypertidy.github.io/laridae/reference/lari_text_outline.md)
  : Text as polygon outlines
- [`lari_glyphs()`](https://hypertidy.github.io/laridae/reference/lari_glyphs.md)
  : Mesh glyph outlines

# Mesh glyph outlines

Turn glyph rings into constraint segments and triangulate them, one mesh
per glyph (the default) or one mesh for the whole string
(`merge = TRUE`). Holes come from the constraint depth: with the default
`erase = "holes"` only odd depth is kept, so a counter (depth 2) is a
hole and the orientation of the rings does not matter. `erase = "outer"`
keeps the counters as part of the mesh (their `depth` tells them apart).

## Usage

``` r
lari_glyphs(
  outline,
  merge = FALSE,
  max_area = NULL,
  min_angle = NULL,
  min_edge_length = NULL,
  erase = c("holes", "outer", "hull"),
  ...
)
```

## Arguments

- outline:

  a data frame of rings, see Details

- merge:

  if TRUE triangulate all glyphs in one mesh, so overlapping glyphs
  cross and stack in `depth`; otherwise mesh each glyph separately and
  bind the tables

- max_area:

  maximum triangle area, NULL for none

- min_angle:

  minimum triangle angle in degrees, NULL for none. Above about 20.7
  degrees termination is not guaranteed by theory; the floor keeps it
  finite.

- min_edge_length:

  the edge-length floor; NULL chooses
  [`default_min_edge_length()`](https://hypertidy.github.io/laridae/reference/default_min_edge_length.md)
  from the current segments and the area bound, taking the smaller of
  `max_area` and the finest area the sizing field asks for so a sizing
  field is honoured rather than capped; 0 never gives up

- erase:

  which triangles to keep: "holes" (odd depth, the letter shapes),
  "outer" (depth \> 0, letters with their counters filled), "hull" (all,
  including the space around each letter)

- ...:

  passed to
  [`lari_triangulate()`](https://hypertidy.github.io/laridae/reference/lari_triangulate.md)
  (`size`, `max_steiner`, ...)

## Value

a list like
[`lari_triangulate()`](https://hypertidy.github.io/laridae/reference/lari_triangulate.md):
`vertices`, `triangles` and `segments` tables (rows of `vertices` index
the whole result) with a `glyph` column (NA for triangles when
`merge = TRUE`), and `report`, one row per mesh. The vertex `id` column
is local to each glyph's mesh.

## Details

`outline` is a data frame with `x`, `y` and ring and glyph id columns.
The output of
[`lari_text_outline()`](https://hypertidy.github.io/laridae/reference/lari_text_outline.md)
(`glyph`, `ring`), of
[`systemfonts::glyph_outline()`](https://systemfonts.r-lib.org/reference/glyph_outline.html)
(`glyph`, `contour`) and of `string2path::string2path()` (`glyph_id`,
`path_id`) are recognised as they are. A ring may repeat its first
vertex at the end, or not.

## See also

[`lari_text()`](https://hypertidy.github.io/laridae/reference/lari_text.md),
[`lari_text_outline()`](https://hypertidy.github.io/laridae/reference/lari_text_outline.md)

## Examples

``` r
## a square "O": an outer ring and a hole ring, as a glyph would give
o <- data.frame(x = c(0, 1, 1, 0, 0.3, 0.7, 0.7, 0.3),
                y = c(0, 0, 1, 1, 0.3, 0.3, 0.7, 0.7),
                glyph = 1L, ring = rep(1:2, each = 4))
r <- lari_glyphs(o, max_area = 0.01)
nrow(r$triangles)
#> [1] 134
```

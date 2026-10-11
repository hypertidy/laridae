# Refine a mesh

Ruppert-style Delaunay refinement with CGAL's `Delaunay_mesher_2`, by
minimum angle, maximum area, and a sizing field. The mesher is kept on
the handle so
[`lari_step()`](https://hypertidy.github.io/laridae/reference/lari_step.md)
can continue it one point at a time; any edit to the mesh discards it.

## Usage

``` r
lari_refine(
  m,
  min_angle = NULL,
  max_area = NULL,
  size = NULL,
  max_steiner = Inf,
  min_edge_length = NULL,
  seeds = NULL,
  erase = c("outer", "holes", "hull")
)
```

## Arguments

- m:

  a mesh from
  [`lari_new()`](https://hypertidy.github.io/laridae/reference/lari_new.md)

- min_angle:

  minimum triangle angle in degrees, NULL for none. Above about 20.7
  degrees termination is not guaranteed by theory; the floor keeps it
  finite.

- max_area:

  maximum triangle area, NULL for none

- size:

  a sizing field giving the local maximum triangle area: a
  `function(x, y)` (called with scalars at each triangle centroid), or a
  grid as `list(x, y, z)` in
  [`graphics::image()`](https://rdrr.io/r/graphics/image.html)
  convention (x and y are cell centres, `z` is `length(x)` by
  `length(y)`; nearest cell, NA is unbounded). Combined with `max_area`
  by taking the smaller bound.

- max_steiner:

  budget of new vertices for this call (`Inf` for none)

- min_edge_length:

  the edge-length floor; NULL chooses
  [`default_min_edge_length()`](https://hypertidy.github.io/laridae/reference/default_min_edge_length.md)
  from the current segments and the area bound, taking the smaller of
  `max_area` and the finest area the sizing field asks for so a sizing
  field is honoured rather than capped; 0 never gives up

- seeds:

  optional points (two-column matrix or list with x, y) marking regions
  NOT to mesh, CGAL style; when given they replace `erase`

- erase:

  which region is meshed: "outer" (everything inside the outermost
  constraints, depth \> 0), "holes" (odd depth only), or "hull"

## Value

the unrefined report as a one-row data frame, invisibly

## Details

The refiner never splits a triangle whose shortest edge is below
`min_edge_length`: that floor is what stops refinement cascading into
sharp input corners. Whatever could not be refined is reported by
[`lari_counts()`](https://hypertidy.github.io/laridae/reference/lari_counts.md)
(`unrefined`) and returned here as a data frame.

## Examples

``` r
x <- c(0, 1, 1, 0); y <- c(0, 0, 1, 1)
m <- lari_new(x, y, 1:4, c(2, 3, 4, 1))
lari_refine(m, max_area = 0.01)
## a sizing field: small triangles near the origin
m2 <- lari_new(x, y, 1:4, c(2, 3, 4, 1))
lari_refine(m2, size = function(x, y) 0.0005 + 0.02 * (x^2 + y^2))
nrow(lari_triangles(m2))
#> [1] 244
```

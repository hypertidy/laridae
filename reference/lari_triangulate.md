# One-shot constrained triangulation

Build a mesh, optionally refine it, and return the tables: the same
shape as `cdtr`'s one-shot call, for use as a drop-in backend.

## Usage

``` r
lari_triangulate(
  x,
  y,
  s0 = NULL,
  s1 = NULL,
  PA = NULL,
  max_area = NULL,
  min_angle = NULL,
  min_edge_length = NULL,
  erase = c("outer", "holes", "hull"),
  ...
)
```

## Arguments

- x, y:

  vertex coordinates (may be omitted for an empty mesh)

- s0, s1:

  1-based indices into `x`/`y` of constraint segment start and end (may
  be NULL)

- PA:

  optional numeric matrix (or data frame) of per-vertex attributes, one
  row per vertex, e.g. `cbind(z_ = z)`. New vertices (crossings, Steiner
  points) get linearly interpolated values. The attribute columns are
  fixed when the mesh is created.

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

  which region is meshed: "outer" (everything inside the outermost
  constraints, depth \> 0), "holes" (odd depth only), or "hull"

- ...:

  passed to
  [`lari_refine()`](https://hypertidy.github.io/laridae/reference/lari_refine.md)
  (`size`, `max_steiner`, `seeds`)

## Value

a list with `vertices`, `triangles`, `segments`, a one-row provenance
`report` (see
[`lari_tables()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)),
`unrefined` (NULL when no refinement was asked for) and
`min_edge_length`

## Examples

``` r
r <- lari_triangulate(c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2, 3, 4, 1), max_area = 0.05)
str(r)
#> List of 7
#>  $ vertices       :'data.frame': 25 obs. of  4 variables:
#>   ..$ x     : num [1:25] 0 1 1 0 0 0.5 1 0.5 0.5 0.25 ...
#>   ..$ y     : num [1:25] 0 0 1 1 0.5 0 0.5 1 0.5 0 ...
#>   ..$ origin: chr [1:25] "input" "input" "input" "input" ...
#>   ..$ id    : int [1:25] 1 2 3 4 5 6 7 8 9 10 ...
#>  $ triangles      :'data.frame': 32 obs. of  5 variables:
#>   ..$ v0            : int [1:32] 15 11 1 18 13 19 9 12 12 2 ...
#>   ..$ v1            : int [1:32] 14 10 10 9 5 13 19 13 4 14 ...
#>   ..$ v2            : int [1:32] 20 18 11 24 24 24 24 19 13 15 ...
#>   ..$ depth         : int [1:32] 1 1 1 1 1 1 1 1 1 1 ...
#>   ..$ depth_distinct: int [1:32] 1 1 1 1 1 1 1 1 1 1 ...
#>  $ segments       :'data.frame': 16 obs. of  4 variables:
#>   ..$ v0     : int [1:16] 4 6 3 1 2 5 7 4 8 6 ...
#>   ..$ v1     : int [1:16] 13 15 17 10 14 11 16 12 12 10 ...
#>   ..$ segment: int [1:16] 4 1 3 1 2 4 2 3 3 1 ...
#>   ..$ count  : int [1:16] 1 1 1 1 1 1 1 1 1 1 ...
#>  $ report         :'data.frame': 1 obs. of  13 variables:
#>   ..$ backend        : chr "laridae"
#>   ..$ package        : chr "0.1.0"
#>   ..$ cgal           : chr "6.2.1"
#>   ..$ erase          : chr "outer"
#>   ..$ refined        : logi TRUE
#>   ..$ min_edge_length: num 0.0559
#>   ..$ bad            : int 0
#>   ..$ short_edge     : int 0
#>   ..$ sharp_corner   : int 0
#>   ..$ outside        : int 0
#>   ..$ inserted       : int 21
#>   ..$ budget_hit     : logi FALSE
#>   ..$ stalled        : logi FALSE
#>  $ unrefined      :'data.frame': 1 obs. of  8 variables:
#>   ..$ bad                : int 0
#>   ..$ shortEdges         : int 0
#>   ..$ sharpFixedCorner   : int 0
#>   ..$ circumcenterOutside: int 0
#>   ..$ inserted           : int 21
#>   ..$ budgetHit          : int 0
#>   ..$ stalled            : int 0
#>   ..$ min_edge_length    : num 0.0559
#>  $ min_edge_length: num 0.0559
#>  $ ids            : int [1:4] 1 2 3 4
```

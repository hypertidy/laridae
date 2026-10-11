# Mesh tables

The three output tables of the shared contract.

## Usage

``` r
lari_tables(m, erase = c("outer", "holes", "hull"))

lari_vertices(m)

lari_triangles(m, erase = c("outer", "holes", "hull"))

lari_segments(m)

lari_depth(m, erase = c("outer", "holes", "hull"))
```

## Arguments

- m:

  a mesh from
  [`lari_new()`](https://hypertidy.github.io/laridae/reference/lari_new.md)

- erase:

  which triangles to return: "outer" (depth \> 0, what Triangle's `-p`
  keeps), "holes" (odd depth), "hull" (all). With no segments every
  triangle is returned.

## Value

a data frame; `lari_tables()` returns the three tables and the `report`
in a list, `lari_depth()` the depth column of the triangles

## Details

- vertices: `x`, `y`, the attribute columns, `origin` ("input",
  "crossing", "steiner") and the stable vertex `id`

- triangles: `v0`, `v1`, `v2` (1-based rows of the vertices table),
  `depth` and `depth_distinct`

- segments: constraint edges `v0`, `v1` (rows of the vertices table),
  the input `segment` id they came from (the lowest, when several
  coincide) and `count`, the number of input segments covering the edge

`depth` is the constraint layer: the number of constraint crossings on
the way in from outside the convex hull, counting an edge covered by k
input segments k times. `depth_distinct` is the same count but a doubled
boundary (an edge covered by several coincident segments) is crossed
once, so it ignores the `count` weighting. For nested rings odd is
inside and even is a hole; for a coverage it orders regions by distance
from the boundary.

`lari_tables()` also returns a one-row `report` data frame recording the
provenance of the tables: `backend` ("laridae"), the laridae `package`
and `cgal` versions, the `erase` region, whether the mesh was `refined`,
the `min_edge_length` floor, and the last refinement's unrefined counts
(`bad`, `short_edge`, `sharp_corner`, `outside`, `inserted`,
`budget_hit`, `stalled`), all NA when the mesh has not been refined.

Row indices are only valid for one snapshot of the tables: use `id` to
follow vertices across edits.

## Examples

``` r
m <- lari_new(c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25),
              c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75),
              1:8, c(2, 3, 4, 1, 6, 7, 8, 5))
table(lari_depth(m))
#> 
#> 1 2 
#> 8 2 
lari_segments(m)
#>   v0 v1 segment count
#> 1  1  4       4     1
#> 2  5  8       8     1
#> 3  3  4       3     1
#> 4  1  2       1     1
#> 5  7  8       7     1
#> 6  5  6       5     1
#> 7  2  3       2     1
#> 8  6  7       6     1
```

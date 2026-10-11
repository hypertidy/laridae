# Create a mesh handle

A laridae mesh is a persistent constrained Delaunay triangulation
(CGAL's `Constrained_triangulation_plus_2` with exact predicates).
Points and constraint segments can be added and removed at any time;
crossing constraints are resolved by inserting the crossing point, and
the constraint hierarchy maps every output edge back to the input
segment it came from.

## Usage

``` r
lari_new(x = NULL, y = NULL, s0 = NULL, s1 = NULL, PA = NULL)
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

## Value

a `laridae_mesh` handle; `attr(m, "ids")` holds the vertex id of each
input row and `attr(m, "segment_ids")` the id of each input segment

## Details

Vertex ids are stable for the life of the handle: removing a vertex
leaves a tombstone and its id is never reused. Duplicate input points
share one id (the first point's attributes are kept).

The handle is an external pointer: it does not survive saving and
reloading an R session.

## Examples

``` r
## a square with a square hole
x <- c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25)
y <- c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75)
m <- lari_new(x, y, 1:8, c(2, 3, 4, 1, 6, 7, 8, 5))
lari_triangles(m)
#>    v0 v1 v2 depth depth_distinct
#> 1   4  1  5     1              1
#> 2   4  5  8     1              1
#> 3   7  4  8     1              1
#> 4   5  6  8     2              2
#> 5   5  1  6     1              1
#> 6   7  3  4     1              1
#> 7   7  6  2     1              1
#> 8   7  8  6     2              2
#> 9   7  2  3     1              1
#> 10  6  1  2     1              1
lari_refine(m, max_area = 0.01, min_angle = 25)
lari_counts(m)
#> $input
#> [1] 8
#> 
#> $crossing
#> [1] 0
#> 
#> $steiner
#> [1] 81
#> 
#> $faces
#> [1] 144
#> 
#> $segments
#> [1] 8
#> 
#> $edges
#> [1] 48
#> 
#> $refined
#> [1] TRUE
#> 
#> $mesher_alive
#> [1] TRUE
#> 
#> $min_edge_length
#> [1] 0.025
#> 
#> $unrefined
#>                 bad          shortEdges    sharpFixedCorner circumcenterOutside 
#>                   0                   0                   0                   0 
#>            inserted           budgetHit             stalled 
#>                  81                   0                   0 
#> 
```

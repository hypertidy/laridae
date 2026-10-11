# Edit a mesh

`lari_add_points()` inserts points (a point on a constraint splits it)
and returns their vertex ids. `lari_add_segments()` inserts constraints
between existing vertex ids, inserting the crossing point where they
cross existing constraints, and returns the new segment ids.
`lari_remove_points()` removes vertices, along with any segment that
ends at them. `lari_remove_segments()` removes constraints by their end
vertex ids (or by segment id with `id`); crossing vertices that no
longer lie on any constraint are removed too, so adding and then
removing a segment leaves the tables as they were.

## Usage

``` r
lari_add_points(m, x, y, PA = NULL)

lari_add_segments(m, s0, s1)

lari_remove_points(m, ids)

lari_remove_segments(m, s0 = NULL, s1 = NULL, id = NULL)
```

## Arguments

- m:

  a mesh from
  [`lari_new()`](https://hypertidy.github.io/laridae/reference/lari_new.md)

- x, y:

  point coordinates

- PA:

  attribute matrix, one row per point, with the mesh's columns

- s0, s1:

  vertex ids of segment ends

- ids:

  vertex ids

- id:

  segment ids (alternative to `s0`/`s1`)

## Value

`lari_add_points()`: integer vertex ids. `lari_add_segments()`: integer
segment ids (NA for a zero-length segment). The removers return the
number removed, invisibly.

## Details

Any edit discards the mesher state: the next
[`lari_refine()`](https://hypertidy.github.io/laridae/reference/lari_refine.md)
or
[`lari_step()`](https://hypertidy.github.io/laridae/reference/lari_step.md)
starts a new mesher on the edited triangulation (which only finds bad
triangles where the edit made them).

## Examples

``` r
m <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1))
ids <- lari_add_points(m, 0.5, 0.5)
lari_add_segments(m, c(1, 2), c(3, 4))    ## crossing diagonals
#> [1] 1 2
lari_vertices(m)
#>     x   y origin id
#> 1 0.0 0.0  input  1
#> 2 1.0 0.0  input  2
#> 3 1.0 1.0  input  3
#> 4 0.0 1.0  input  4
#> 5 0.5 0.5  input  5
lari_remove_segments(m, 2, 4)
lari_vertices(m)
#>     x   y origin id
#> 1 0.0 0.0  input  1
#> 2 1.0 0.0  input  2
#> 3 1.0 1.0  input  3
#> 4 0.0 1.0  input  4
#> 5 0.5 0.5  input  5
```

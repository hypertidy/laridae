# Mesh counts

Vertex counts by origin, face and segment counts, and the report from
the last refinement: `bad` triangles still failing a criterion, and of
those how many have a short edge (below the floor), touch a sharp
constrained corner, or have their circumcentre outside the meshed
domain; `inserted` vertices, whether the `max_steiner` budget stopped
it, and `stalled` (the mesher stopped making progress; should be 0).

## Usage

``` r
lari_counts(m)
```

## Arguments

- m:

  a mesh from
  [`lari_new()`](https://hypertidy.github.io/laridae/reference/lari_new.md)

## Value

a list

## Examples

``` r
## a square with a square hole: two closed rings of segments
x <- c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25)
y <- c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75)
m <- lari_new(x, y, s0 = 1:8, s1 = c(2, 3, 4, 1, 6, 7, 8, 5))
lari_counts(m)$steiner
#> [1] 0
lari_refine(m, max_area = 0.01, min_angle = 25)
lari_counts(m)$steiner
#> [1] 81
```

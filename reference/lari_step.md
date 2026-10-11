# Step the mesher

Insert up to `n` refinement points with CGAL's step-by-step mesher,
using the criteria from the last
[`lari_refine()`](https://hypertidy.github.io/laridae/reference/lari_refine.md)
call. After an edit the mesher is rebuilt on the edited mesh, so
stepping refines only what the edit spoiled.

## Usage

``` r
lari_step(m, n = 1L)
```

## Arguments

- m:

  a mesh from
  [`lari_new()`](https://hypertidy.github.io/laridae/reference/lari_new.md)

- n:

  maximum number of new vertices

## Value

the number of vertices inserted

## Examples

``` r
m <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2, 3, 4, 1))
lari_refine(m, max_area = 0.01, max_steiner = 0)
lari_step(m, 5)
#> [1] 5
lari_counts(m)$steiner
#> [1] 5
```

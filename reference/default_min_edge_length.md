# Default refinement edge-length floor

`min_edge_frac` times the median constraint segment length, which keeps
the refiner from cascading into sharp input corners, capped at
`area_edge_frac * sqrt(max_area)` so the floor never blocks the area
target (a triangle of area A has edges of order sqrt(A)). With no
segments only the area cap applies; with neither, 0. Identical to
[`cdtr::default_min_edge_length()`](https://hypertidy.github.io/cdtr/reference/default_min_edge_length.html).

## Usage

``` r
default_min_edge_length(
  x,
  y,
  s0,
  s1,
  max_area = NULL,
  min_edge_frac = 0.3,
  area_edge_frac = 0.25
)
```

## Arguments

- x, y:

  vertex coordinates

- s0, s1:

  1-based segment end indices into `x`/`y`

- max_area:

  the area target, or NULL

- min_edge_frac:

  fraction of the median segment length

- area_edge_frac:

  fraction of `sqrt(max_area)`

## Value

a single number

## Examples

``` r
x <- c(0, 1, 1, 0)
y <- c(0, 0, 1, 1)
s0 <- 1:4
s1 <- c(2:4, 1)
## 0.3 times the median segment length
default_min_edge_length(x, y, s0, s1)
#> [1] 0.3
## a small area target caps the floor at 0.25 * sqrt(max_area)
default_min_edge_length(x, y, s0, s1, max_area = 0.01)
#> [1] 0.025
## no segments and no area target: no floor
default_min_edge_length(x, y, integer(0), integer(0))
#> [1] 0
```

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

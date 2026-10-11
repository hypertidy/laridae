# laridae

<!-- badges: start -->
[![R-CMD-check](https://github.com/hypertidy/laridae/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hypertidy/laridae/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Constrained Delaunay triangulation and meshing for R with
[CGAL](https://www.cgal.org/): a persistent mesh handle you can edit and
refine, with the same vertices / segments / triangles contract as
[cdtr](https://github.com/hypertidy/cdtr).

laridae is the CGAL-backed member of the hypertidy meshing stack. cdtr is the
header-only, builds-anywhere baseline; laridae is the ceiling: everything
CGAL's 2D constrained triangulations and Mesh_2 can do, exposed in the same
shape so the backend is a choice, not a rewrite.

* fully dynamic: points and constraints can be inserted and removed at any
  time (`Constrained_triangulation_plus_2` over a constrained Delaunay
  triangulation with exact predicates), vertex ids are stable for the life of
  the handle
* crossing constraints are resolved by inserting the crossing, and every
  output edge maps back to the input segment it came from
* `depth` per triangle: constraint crossings from the outside, computed
  topologically (odd inside, even hole for nested rings; matches cdtr)
* refinement by minimum angle and maximum area with CGAL's
  `Delaunay_mesher_2`, an edge-length floor, and a report of what could not
  be refined
* step-by-step refinement, and re-refinement after an edit that only touches
  the edited neighbourhood
* sizing fields: the local maximum triangle area as a function of position
  or a grid

laridae is not aimed at CRAN: CGAL's Mesh_2 is GPL and the toolchain is
heavy, so it optimises for capability and correctness.

## Installation

laridae needs the CGAL (>= 6.0) and Boost headers; CGAL is header-only so
nothing is linked (no GMP: the exact-predicates kernel is enough).

* macOS: `brew install cgal`
* Linux: distributions with CGAL 6 (`libcgal-dev`), or download the
  [CGAL release](https://github.com/CGAL/cgal/releases) "library" tarball and
  set `CGAL_INCLUDE_DIR` to its `include/` directory; Boost from
  `libboost-dev`
* anywhere: `install.packages(c("RcppCGAL", "BH"))` and the configure script
  finds their headers

```r
remotes::install_github("hypertidy/laridae")
```

## Usage

```r
library(laridae)
## a square with a square hole: two closed rings of segments
x <- c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25)
y <- c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75)
m <- lari_new(x, y, s0 = 1:8, s1 = c(2, 3, 4, 1, 6, 7, 8, 5))
table(lari_depth(m))        # 1 = in the outer ring, 2 = in the hole

lari_refine(m, max_area = 0.01, min_angle = 25)
lari_counts(m)

## edit and re-refine: only the neighbourhood of the edit is touched
ids <- lari_add_points(m, c(0.1, 0.15), c(0.1, 0.12))
lari_add_segments(m, ids[1], ids[2])
lari_refine(m, max_area = 0.01, min_angle = 25)

## or one point at a time
lari_step(m, n = 10)

## a sizing field: local maximum area as a function of position
m2 <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2, 3, 4, 1))
lari_refine(m2, size = function(x, y) 0.0005 + 0.01 * x)

## the contract tables
lari_vertices(m)    # x, y, attributes, origin (input/crossing/steiner), id
lari_triangles(m)   # v0, v1, v2 (rows of the vertices table), depth
lari_segments(m)    # v0, v1, input segment id, count of covering segments
```

`lari_triangulate()` is the one-shot form, returning the three tables like
cdtr's `cdt_triangulate()`. Per-vertex attributes (`PA = cbind(z_ = z)`) ride
along: crossings and Steiner points get linearly interpolated values.

## API

| function | |
|---|---|
| `lari_new(x, y, s0, s1, PA)` | create a handle (empty with no arguments) |
| `lari_add_points(m, x, y, PA)` | insert points, returns stable ids |
| `lari_add_segments(m, s0, s1)` | insert constraints between ids, crossings inserted |
| `lari_remove_points(m, ids)` | remove vertices and the segments ending at them |
| `lari_remove_segments(m, s0, s1, id)` | remove constraints (and crossings left without one) |
| `lari_refine(m, min_angle, max_area, size, max_steiner, min_edge_length, seeds, erase)` | Mesh_2 refinement |
| `lari_step(m, n)` | step-by-step refinement with the last criteria |
| `lari_vertices`, `lari_triangles`, `lari_segments`, `lari_depth`, `lari_tables` | output tables |
| `lari_counts(m)` | counts by origin and the unrefined report |

## Benchmarks

`inst/benchmarks/` runs laridae against cdtr and RTriangle on sf's North
Carolina counties and anglr's Tasmanian contours and cadastre
(`results.txt` holds the last full run). On one Linux core (CGAL 6.1,
R 4.3), nc at max_area = A/5000 with min_angle = 20:

| | median |
|---|---|
| RTriangle (Triangle) | 5.8 ms |
| laridae | 15 ms |
| cdtr | 19 ms |

Constrained-only output (no refinement) is identical across the three on
all cases. For bare points (`points.R`) CGAL is the fastest: a million normal
points triangulate in 1.9 s including table extraction, against 2.5 s for
cdtr and 3.5 s for RTriangle.

After a small edit (a short new constraint) a second refine of the refined
nc mesh takes 3 ms and inserts 6 vertices, against 16 ms for a rebuild.

## History

The original laridae (2017-2022, Rcpp and cgalh experiments with
point triangulation and segment insertion) is preserved on the
[`legacy-rcpp`](https://github.com/hypertidy/laridae/tree/legacy-rcpp)
branch.

## Licence

GPL (>= 3), as required by CGAL's 2D meshing package.

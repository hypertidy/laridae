# Changelog

## laridae 0.1.0

- Rebuilt from scratch on CGAL 6 (`Constrained_triangulation_plus_2`
  with exact predicates and `Delaunay_mesher_2`) behind a persistent
  cpp11 handle:
  [`lari_new()`](https://hypertidy.github.io/laridae/reference/lari_new.md),
  [`lari_add_points()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md),
  [`lari_add_segments()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md),
  [`lari_remove_points()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md),
  [`lari_remove_segments()`](https://hypertidy.github.io/laridae/reference/lari_add_points.md),
  [`lari_refine()`](https://hypertidy.github.io/laridae/reference/lari_refine.md),
  [`lari_step()`](https://hypertidy.github.io/laridae/reference/lari_step.md),
  and the contract tables
  [`lari_vertices()`](https://hypertidy.github.io/laridae/reference/lari_tables.md),
  [`lari_triangles()`](https://hypertidy.github.io/laridae/reference/lari_tables.md),
  [`lari_segments()`](https://hypertidy.github.io/laridae/reference/lari_tables.md),
  [`lari_depth()`](https://hypertidy.github.io/laridae/reference/lari_tables.md),
  [`lari_counts()`](https://hypertidy.github.io/laridae/reference/lari_counts.md).
- Sizing fields: `lari_refine(size = )` takes a function of position or
  a grid giving the local maximum triangle area. The default edge-length
  floor now accounts for the sizing field, so a `size` argument is
  honoured instead of being capped at the coarse input-edge scale when
  `min_edge_length` is left at its default.
- Hull-edge Steiner points created during refinement now get attributes
  interpolated along the nearest hull edge, rather than copied from the
  single nearest vertex (fixes attribute error at map scale).
- [`lari_triangles()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)
  (and
  [`lari_tables()`](https://hypertidy.github.io/laridae/reference/lari_tables.md))
  gain a `depth_distinct` column: the constraint depth with a doubled
  boundary counted once, matching `cdtr`’s `depth_distinct`.
- [`lari_tables()`](https://hypertidy.github.io/laridae/reference/lari_tables.md)
  and
  [`lari_triangulate()`](https://hypertidy.github.io/laridae/reference/lari_triangulate.md)
  now return a one-row `report` with the backend, laridae and CGAL
  versions, the erase region, the edge floor, and the last refinement’s
  unrefined counts.
- Licence is now GPL (\>= 3), as required by CGAL’s Mesh_2.
- CGAL (\>= 6.0) and Boost headers are supplied by the CRAN packages
  `RcppCGAL` and `BH` via `LinkingTo`, so no system CGAL is required and
  the compiled code passes `R CMD check --as-cran`. For development, set
  `CGAL_INCLUDE_DIR` to build against stock CGAL headers instead (see
  README; that route is not CRAN-clean).
- Builds on macOS and Windows: CGAL 6’s
  `Constrained_triangulation_plus_2` includes
  `boost/stl_interfaces/iterator_interface.hpp`, which BH does not ship,
  so the three Boost.STLInterfaces headers it needs are vendored in
  `src/boost-extra` (Boost Software License). Linux only built before
  because the system Boost filled the gap. Windows also gets a
  `src/Makevars.win`.
- The previous Rcpp/cgalh code is preserved on the `legacy-rcpp` branch.

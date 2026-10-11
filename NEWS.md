# laridae 0.1.0

* Rebuilt from scratch on CGAL 6 (`Constrained_triangulation_plus_2` with
  exact predicates and `Delaunay_mesher_2`) behind a persistent cpp11 handle:
  `lari_new()`, `lari_add_points()`, `lari_add_segments()`,
  `lari_remove_points()`, `lari_remove_segments()`, `lari_refine()`,
  `lari_step()`, and the contract tables `lari_vertices()`,
  `lari_triangles()`, `lari_segments()`, `lari_depth()`, `lari_counts()`.
* Sizing fields: `lari_refine(size = )` takes a function of position or a
  grid giving the local maximum triangle area. The default edge-length floor
  now accounts for the sizing field, so a `size` argument is honoured instead
  of being capped at the coarse input-edge scale when `min_edge_length` is
  left at its default.
* Hull-edge Steiner points created during refinement now get attributes
  interpolated along the nearest hull edge, rather than copied from the
  single nearest vertex (fixes attribute error at map scale).
* `lari_triangles()` (and `lari_tables()`) gain a `depth_distinct` column: the
  constraint depth with a doubled boundary counted once, matching `cdtr`'s
  `depth_distinct`.
* Licence is now GPL (>= 3), as required by CGAL's Mesh_2.
* CGAL (>= 6.0) and Boost headers are supplied by the CRAN packages
  `RcppCGAL` and `BH` via `LinkingTo`, so no system CGAL is required and the
  compiled code passes `R CMD check --as-cran`. For development, set
  `CGAL_INCLUDE_DIR` to build against stock CGAL headers instead (see
  README; that route is not CRAN-clean).
* Builds on macOS and Windows: CGAL 6's `Constrained_triangulation_plus_2`
  includes `boost/stl_interfaces/iterator_interface.hpp`, which BH does not
  ship, so the three Boost.STLInterfaces headers it needs are vendored in
  `src/boost-extra` (Boost Software License). Linux only built before because
  the system Boost filled the gap. Windows also gets a `src/Makevars.win`.
* The previous Rcpp/cgalh code is preserved on the `legacy-rcpp` branch.

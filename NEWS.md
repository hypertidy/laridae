# laridae (development version)

* New `lari_cdt()`: a one-shot constrained triangulation on CGAL's exact
  kernel (or the inexact one), returning each vertex as its nearest double
  plus exact numerator and denominator strings. It returns the same tables as
  `lari_tables()`: triangle `depth` and `depth_distinct`, segment `segment`
  and `count`, and `edge_sources`, and takes `erase`.

* `lari_tables()` and `lari_triangulate()` return `edge_sources` (mesh spec
  v0.2), and `lari_edge_sources()` returns it alone: one row per constraint
  edge and covering input segment (`edge`, `segment`, `forward`), from CGAL's
  constraint contexts, so every coincident or collinear input is listed with
  its direction. `segments$segment` and `segments$count` are the lowest and
  the number of these rows.

* Meshed text: `lari_text()` shapes a string in any installed font and meshes
  its glyphs as polygons with holes; `lari_text_outline()` returns the glyph
  rings (via 'textshaping' and 'systemfonts', both in Suggests) and
  `lari_glyphs()` meshes rings from any source, including the output of
  the 'string2path' package. New article "Meshed text".

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
* `lari_tables()` and `lari_triangulate()` now return a one-row `report` with
  the backend, laridae and CGAL versions, the erase region, the edge floor,
  and the last refinement's unrefined counts.
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

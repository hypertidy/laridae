# laridae 0.1.0.9000

* Rebuilt from scratch on CGAL 6 (`Constrained_triangulation_plus_2` with
  exact predicates and `Delaunay_mesher_2`) behind a persistent cpp11 handle:
  `lari_new()`, `lari_add_points()`, `lari_add_segments()`,
  `lari_remove_points()`, `lari_remove_segments()`, `lari_refine()`,
  `lari_step()`, and the contract tables `lari_vertices()`,
  `lari_triangles()`, `lari_segments()`, `lari_depth()`, `lari_counts()`.
* Sizing fields: `lari_refine(size = )` takes a function of position or a
  grid giving the local maximum triangle area.
* Licence is now GPL (>= 3), as required by CGAL's Mesh_2.
* The previous Rcpp/cgalh code is preserved on the `legacy-rcpp` branch.

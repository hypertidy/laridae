#' laridae: constrained triangulation and meshing with CGAL
#'
#' A persistent constrained Delaunay triangulation handle backed by CGAL.
#' See [lari_new()] for the handle API and [lari_triangulate()] for the
#' one-shot form.
#'
#' @keywords internal
#' @useDynLib laridae, .registration = TRUE
## Rcpp is pulled in by RcppCGAL's patched CGAL headers (the RNG wrapper needs
## the Rcpp namespace at run time); this token import keeps it a real dependency.
#' @importFrom Rcpp evalCpp
"_PACKAGE"

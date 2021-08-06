#' CGAL point triangulation (unconstrained)
#'
#' `tri_xy` CGAL vertex index
#'
#' First method uses uses a faces iterator to extract the vertex->info for
#' each face. A Delaunay triangulation has both finite and infinite faces
#' (see CGAL documentation). The infinite faces join to an external, infinite
#' vertex, so the finite_faces_iterator just includes the internal faces.
#'
#' vertex index
#' @param x coordinate vector
#' @param y coordinate vector
#' @export
#' @return triangle index, 1-based
#' @name tri_xy
#' @export
tri_xy <- function(x, y) {
  tri_xy_cpp(x, y) + 1
}

#' `tri_xy1` CGAL vertex index MP version#2
#'
#' This method uses a vertex iterator instead of a faces iterator.
#'
#' @export
#' @name tri_xy
#' @return triangle index, 1-based
tri_xy1 <- function(x, y) {
  tri_xy1_cpp(x, y) + 1
}

#' `tri_xy2` CGAL vertex index MP version#3
#'
#' This is the long-hand way, using an iteration over all faces, checking
#' whether they are finite or not, and accessing the face.vertex info by
#' dereferencing pointers to each vertex of the face.
#'
#' @export
#' @name tri_xy
#' @return triangle index, 1-based
tri_xy2 <- function(x, y) {
  tri_xy2_cpp(x, y) + 1
}

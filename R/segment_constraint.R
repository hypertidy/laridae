#' Triangulate segments
#'
#' @param x anything SC-able
#' @param ... ignored
#'
#' @return nothing useful, dummy NA
#' @export
#' @import silicate
#' @examples
#' segment_constraint(silicate::minimal_mesh)
segment_constraint <- function(x, ...) {
  if (!inherits(x, "SC")) {
    x <- silicate::SC(x)
  }

  X <- x$vertex$x_
  Y <- x$vertex$y_
  ## internal 0-based C++ index
  l <- rbind(match(x$edge$.vx0, x$vertex$vertex_) - 1,
             match(x$edge$.vx1, x$vertex$vertex_) - 1)
 ## dummy return value for now
  segment_constraint_cpp(X, Y, split(l, rep(seq_len(ncol(l)), each = 2)))
}


#' Insert segment constraint
#'
#' @param x x coordinate
#' @param y y coordinate
#' @param v0 segment start index (1-based)
#' @param v1 segment end index (1-based)
#' @export
insert_constraint <- function(x, y, v0, v1) {
  insert_constraint_cpp(x, y, v0 - 1, v1 - 1)
}
#' Insert segment constraint
#'
#' @param x x coordinate
#' @param y y coordinate
#' @param v0 segment start index (1-based)
#' @param v1 segment end index (1-based)
#' @export
insert_mesh <- function(x, y, v0, v1) {
  insert_mesh_cpp(x =  x, y = y, v0 = v0 - 1, v1 = v1 - 1)
}


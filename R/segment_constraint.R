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

## the domain codes shared with the C++ side
erase_code <- function(erase) {
  match(match.arg(erase, c("outer", "hull", "holes")), c("hull", "outer", "holes")) - 1L
}

as_PA <- function(PA, n) {
  if (is.null(PA)) return(matrix(0, n, 0L))
  PA <- as.matrix(PA)
  if (nrow(PA) != n) stop("PA must have one row per vertex")
  if (ncol(PA) > 0L && is.null(colnames(PA))) colnames(PA) <- paste0("a", seq_len(ncol(PA)), "_")
  storage.mode(PA) <- "double"
  PA
}

check_mesh <- function(m) {
  if (!inherits(m, "laridae_mesh")) stop("not a laridae mesh: create one with lari_new()")
  invisible(m)
}

#' Create a mesh handle
#'
#' A laridae mesh is a persistent constrained Delaunay triangulation (CGAL's
#' `Constrained_triangulation_plus_2` with exact predicates). Points and
#' constraint segments can be added and removed at any time; crossing
#' constraints are resolved by inserting the crossing point, and the
#' constraint hierarchy maps every output edge back to the input segment it
#' came from.
#'
#' Vertex ids are stable for the life of the handle: removing a vertex
#' leaves a tombstone and its id is never reused. Duplicate input points
#' share one id (the first point's attributes are kept).
#'
#' The handle is an external pointer: it does not survive saving and
#' reloading an R session.
#'
#' @param x,y vertex coordinates (may be omitted for an empty mesh)
#' @param s0,s1 1-based indices into `x`/`y` of constraint segment start and
#'   end (may be NULL)
#' @param PA optional numeric matrix (or data frame) of per-vertex attributes,
#'   one row per vertex, e.g. `cbind(z_ = z)`. New vertices (crossings,
#'   Steiner points) get linearly interpolated values. The attribute columns
#'   are fixed when the mesh is created.
#' @return a `laridae_mesh` handle; `attr(m, "ids")` holds the vertex id of
#'   each input row and `attr(m, "segment_ids")` the id of each input segment
#' @export
#' @examples
#' ## a square with a square hole
#' x <- c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25)
#' y <- c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75)
#' m <- lari_new(x, y, 1:8, c(2, 3, 4, 1, 6, 7, 8, 5))
#' lari_triangles(m)
#' lari_refine(m, max_area = 0.01, min_angle = 25)
#' lari_counts(m)
lari_new <- function(x = NULL, y = NULL, s0 = NULL, s1 = NULL, PA = NULL) {
  if (is.null(x) != is.null(y)) stop("give both x and y, or neither")
  n <- length(x)
  if (length(y) != n) stop("x and y must be the same length")
  if (!is.null(PA)) PA <- as_PA(PA, n)
  if (!is.null(PA) && ncol(PA) == 0L) PA <- NULL
  nms <- if (is.null(PA) || ncol(PA) == 0L) character(0) else colnames(PA)
  xp <- lari_new_cpp(nms)
  m <- structure(xp, class = "laridae_mesh")
  ids <- if (n > 0L) lari_add_points(m, x, y, PA) else integer(0)
  sids <- integer(0)
  if (length(s0) > 0L) {
    if (length(s0) != length(s1)) stop("s0 and s1 must be the same length")
    s0 <- as.integer(s0); s1 <- as.integer(s1)
    if (anyNA(s0) || anyNA(s1) || any(c(s0, s1) < 1L | c(s0, s1) > n)) stop("segment indices must be in 1..length(x)")
    sids <- lari_add_segments(m, ids[s0], ids[s1])
  }
  attr(m, "ids") <- ids
  attr(m, "segment_ids") <- sids
  m
}

#' @export
print.laridae_mesh <- function(x, ...) {
  k <- lari_counts(x)
  cat("<laridae_mesh>", k$input + k$crossing + k$steiner, "vertices",
      sprintf("(%d input, %d crossing, %d steiner),", k$input, k$crossing, k$steiner),
      k$segments, "segments\n")
  invisible(x)
}

#' Edit a mesh
#'
#' `lari_add_points()` inserts points (a point on a constraint splits it) and
#' returns their vertex ids. `lari_add_segments()` inserts constraints
#' between existing vertex ids, inserting the crossing point where they cross
#' existing constraints, and returns the new segment ids.
#' `lari_remove_points()` removes vertices, along with any segment that ends
#' at them. `lari_remove_segments()` removes constraints by their end vertex
#' ids (or by segment id with `id`); crossing vertices that no longer lie on
#' any constraint are removed too, so adding and then removing a segment
#' leaves the tables as they were.
#'
#' Any edit discards the mesher state: the next [lari_refine()] or
#' [lari_step()] starts a new mesher on the edited triangulation (which only
#' finds bad triangles where the edit made them).
#'
#' @param m a mesh from [lari_new()]
#' @param x,y point coordinates
#' @param PA attribute matrix, one row per point, with the mesh's columns
#' @param s0,s1 vertex ids of segment ends
#' @param ids vertex ids
#' @param id segment ids (alternative to `s0`/`s1`)
#' @return `lari_add_points()`: integer vertex ids. `lari_add_segments()`:
#'   integer segment ids (NA for a zero-length segment). The removers return
#'   the number removed, invisibly.
#' @export
#' @examples
#' m <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1))
#' ids <- lari_add_points(m, 0.5, 0.5)
#' lari_add_segments(m, c(1, 2), c(3, 4))    ## crossing diagonals
#' lari_vertices(m)
#' lari_remove_segments(m, 2, 4)
#' lari_vertices(m)
lari_add_points <- function(m, x, y, PA = NULL) {
  check_mesh(m)
  if (length(x) != length(y)) stop("x and y must be the same length")
  nms <- lari_attr_names_cpp(m)
  if (length(nms) > 0L) {
    if (is.null(PA)) {
      PA <- matrix(NA_real_, length(x), length(nms), dimnames = list(NULL, nms))
    }
    PA <- as_PA(PA, length(x))
    if (ncol(PA) != length(nms)) stop("PA must have columns ", paste(nms, collapse = ", "))
    if (!is.null(colnames(PA)) && all(nms %in% colnames(PA))) PA <- PA[, nms, drop = FALSE]
  } else {
    if (!is.null(PA) && NCOL(PA) > 0L) warning("this mesh was created without attributes; PA ignored")
    PA <- matrix(0, length(x), 0L)
  }
  lari_add_points_cpp(m, as.double(x), as.double(y), PA)
}

#' @rdname lari_add_points
#' @export
lari_add_segments <- function(m, s0, s1) {
  check_mesh(m)
  if (length(s0) != length(s1)) stop("s0 and s1 must be the same length")
  lari_add_segments_cpp(m, as.integer(s0), as.integer(s1))
}

#' @rdname lari_add_points
#' @export
lari_remove_points <- function(m, ids) {
  check_mesh(m)
  invisible(lari_remove_points_cpp(m, as.integer(ids)))
}

#' @rdname lari_add_points
#' @export
lari_remove_segments <- function(m, s0 = NULL, s1 = NULL, id = NULL) {
  check_mesh(m)
  if (length(s0) != length(s1)) stop("s0 and s1 must be the same length")
  invisible(lari_remove_segments_cpp(m, as.integer(s0), as.integer(s1), as.integer(id)))
}

#' Refine a mesh
#'
#' Ruppert-style Delaunay refinement with CGAL's `Delaunay_mesher_2`, by
#' minimum angle, maximum area, and a sizing field. The mesher is kept on the
#' handle so [lari_step()] can continue it one point at a time; any edit to
#' the mesh discards it.
#'
#' The refiner never splits a triangle whose shortest edge is below
#' `min_edge_length`: that floor is what stops refinement cascading into
#' sharp input corners. Whatever could not be refined is reported by
#' [lari_counts()] (`unrefined`) and returned here as a data frame.
#'
#' @param m a mesh from [lari_new()]
#' @param min_angle minimum triangle angle in degrees, NULL for none. Above
#'   about 20.7 degrees termination is not guaranteed by theory; the floor
#'   keeps it finite.
#' @param max_area maximum triangle area, NULL for none
#' @param size a sizing field giving the local maximum triangle area: a
#'   `function(x, y)` (called with scalars at each triangle centroid), or a
#'   grid as `list(x, y, z)` in [graphics::image()] convention (x and y are
#'   cell centres, `z` is `length(x)` by `length(y)`; nearest cell, NA is
#'   unbounded). Combined with `max_area` by taking the smaller bound.
#' @param max_steiner budget of new vertices for this call (`Inf` for none)
#' @param min_edge_length the edge-length floor; NULL chooses
#'   [default_min_edge_length()] from the current segments and `max_area`, 0
#'   never gives up
#' @param seeds optional points (two-column matrix or list with x, y) marking
#'   regions NOT to mesh, CGAL style; when given they replace `erase`
#' @param erase which region is meshed: "outer" (everything inside the
#'   outermost constraints, depth > 0), "holes" (odd depth only), or "hull"
#' @return the unrefined report as a one-row data frame, invisibly
#' @export
#' @examples
#' x <- c(0, 1, 1, 0); y <- c(0, 0, 1, 1)
#' m <- lari_new(x, y, 1:4, c(2, 3, 4, 1))
#' lari_refine(m, max_area = 0.01)
#' ## a sizing field: small triangles near the origin
#' m2 <- lari_new(x, y, 1:4, c(2, 3, 4, 1))
#' lari_refine(m2, size = function(x, y) 0.0005 + 0.02 * (x^2 + y^2))
#' nrow(lari_triangles(m2))
lari_refine <- function(m, min_angle = NULL, max_area = NULL, size = NULL,
                        max_steiner = Inf, min_edge_length = NULL, seeds = NULL,
                        erase = c("outer", "holes", "hull")) {
  check_mesh(m)
  erase <- match.arg(erase)
  if (is.null(min_angle) && is.null(max_area) && is.null(size)) {
    stop("give at least one of min_angle, max_area, size")
  }
  if (is.null(min_edge_length)) {
    ## from the input segments, not their (possibly split) edges
    s <- lari_input_segments_cpp(m)
    n <- nrow(s)
    min_edge_length <- default_min_edge_length(c(s[, 1], s[, 3]), c(s[, 2], s[, 4]),
                                               seq_len(n), n + seq_len(n), max_area)
  }
  fun <- NULL
  gx <- gy <- gz <- double(0)
  if (is.function(size)) {
    fun <- size
  } else if (!is.null(size)) {
    if (!all(c("x", "y", "z") %in% names(size))) stop("size must be a function(x, y) or a list(x, y, z)")
    gx <- as.double(size$x); gy <- as.double(size$y); gz <- as.double(size$z)
    if (length(gz) != length(gx) * length(gy)) stop("size$z must be length(size$x) by length(size$y)")
    if (any(diff(gx) <= 0) || any(diff(gy) <= 0)) stop("size$x and size$y must be increasing")
  }
  sx <- sy <- double(0)
  if (!is.null(seeds)) {
    if (is.list(seeds) && !is.data.frame(seeds)) seeds <- cbind(seeds$x, seeds$y)
    seeds <- as.matrix(seeds)
    sx <- as.double(seeds[, 1]); sy <- as.double(seeds[, 2])
  }
  lari_refine_cpp(m,
                  if (is.null(min_angle)) -1 else as.double(min_angle),
                  if (is.null(max_area)) -1 else as.double(max_area),
                  as.double(min_edge_length), fun, gx, gy, gz,
                  erase_code(erase), sx, sy, as.double(max_steiner))
  invisible(unrefined_frame(m, min_edge_length))
}

#' Step the mesher
#'
#' Insert up to `n` refinement points with CGAL's step-by-step mesher, using
#' the criteria from the last [lari_refine()] call. After an edit the mesher
#' is rebuilt on the edited mesh, so stepping refines only what the edit
#' spoiled.
#'
#' @param m a mesh from [lari_new()]
#' @param n maximum number of new vertices
#' @return the number of vertices inserted
#' @export
#' @examples
#' m <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2, 3, 4, 1))
#' lari_refine(m, max_area = 0.01, max_steiner = 0)
#' lari_step(m, 5)
#' lari_counts(m)$steiner
lari_step <- function(m, n = 1L) {
  check_mesh(m)
  lari_step_cpp(m, as.integer(n))
}

unrefined_frame <- function(m, min_edge_length = NA_real_) {
  u <- lari_counts_cpp(m)$unrefined
  data.frame(as.list(u), min_edge_length = min_edge_length)
}

#' Mesh tables
#'
#' The three output tables of the shared contract.
#'
#' * vertices: `x`, `y`, the attribute columns, `origin` ("input",
#'   "crossing", "steiner") and the stable vertex `id`
#' * triangles: `v0`, `v1`, `v2` (1-based rows of the vertices table) and
#'   `depth`
#' * segments: constraint edges `v0`, `v1` (rows of the vertices table), the
#'   input `segment` id they came from (the lowest, when several coincide)
#'   and `count`, the number of input segments covering the edge
#'
#' `depth` is the constraint layer: the number of constraint crossings on the
#' way in from outside the convex hull, counting an edge covered by k input
#' segments k times. For nested rings odd is inside and even is a hole; for a
#' coverage it orders regions by distance from the boundary.
#'
#' Row indices are only valid for one snapshot of the tables: use `id` to
#' follow vertices across edits.
#'
#' @param m a mesh from [lari_new()]
#' @param erase which triangles to return: "outer" (depth > 0, what
#'   Triangle's `-p` keeps), "holes" (odd depth), "hull" (all). With no
#'   segments every triangle is returned.
#' @return a data frame; `lari_tables()` returns all three in a list,
#'   `lari_depth()` the depth column of the triangles
#' @export
#' @examples
#' m <- lari_new(c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25),
#'               c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75),
#'               1:8, c(2, 3, 4, 1, 6, 7, 8, 5))
#' table(lari_depth(m))
#' lari_segments(m)
lari_tables <- function(m, erase = c("outer", "holes", "hull")) {
  check_mesh(m)
  out <- lari_tables_cpp(m, erase_code(match.arg(erase)))
  out$vertices$origin <- c("input", "crossing", "steiner")[out$vertices$origin + 1L]
  out
}

#' @rdname lari_tables
#' @export
lari_vertices <- function(m) lari_tables(m)$vertices

#' @rdname lari_tables
#' @export
lari_triangles <- function(m, erase = c("outer", "holes", "hull")) lari_tables(m, match.arg(erase))$triangles

#' @rdname lari_tables
#' @export
lari_segments <- function(m) lari_tables(m)$segments

#' @rdname lari_tables
#' @export
lari_depth <- function(m, erase = c("outer", "holes", "hull")) lari_triangles(m, match.arg(erase))$depth

#' Mesh counts
#'
#' Vertex counts by origin, face and segment counts, and the report from the
#' last refinement: `bad` triangles still failing a criterion, and of those
#' how many have a short edge (below the floor), touch a sharp constrained
#' corner, or have their circumcentre outside the meshed domain; `inserted`
#' vertices, whether the `max_steiner` budget stopped it, and `stalled` (the
#' mesher stopped making progress; should be 0).
#'
#' @param m a mesh from [lari_new()]
#' @return a list
#' @export
lari_counts <- function(m) {
  check_mesh(m)
  lari_counts_cpp(m)
}

#' Default refinement edge-length floor
#'
#' `min_edge_frac` times the median constraint segment length, which keeps
#' the refiner from cascading into sharp input corners, capped at
#' `area_edge_frac * sqrt(max_area)` so the floor never blocks the area
#' target (a triangle of area A has edges of order sqrt(A)). With no
#' segments only the area cap applies; with neither, 0. Identical to
#' `cdtr::default_min_edge_length()`.
#'
#' @param x,y vertex coordinates
#' @param s0,s1 1-based segment end indices into `x`/`y`
#' @param max_area the area target, or NULL
#' @param min_edge_frac fraction of the median segment length
#' @param area_edge_frac fraction of `sqrt(max_area)`
#' @return a single number
#' @export
default_min_edge_length <- function(x, y, s0, s1, max_area = NULL,
                                    min_edge_frac = 0.3, area_edge_frac = 0.25) {
  seg <- Inf
  if (length(s0) > 0L) {
    len <- sqrt((x[s0] - x[s1])^2 + (y[s0] - y[s1])^2)
    len <- len[len > 0]
    if (length(len) > 0L) seg <- min_edge_frac * stats::median(len)
  }
  cap <- if (is.null(max_area)) Inf else area_edge_frac * sqrt(max_area)
  out <- min(seg, cap)
  if (is.infinite(out)) 0 else out
}

#' One-shot constrained triangulation
#'
#' Build a mesh, optionally refine it, and return the tables: the
#' same shape as `cdtr`'s one-shot call, for use as a drop-in backend.
#'
#' @inheritParams lari_new
#' @inheritParams lari_refine
#' @param ... passed to [lari_refine()] (`size`, `max_steiner`, `seeds`)
#' @return a list with `vertices`, `triangles`, `segments`, `unrefined`
#'   (NULL when no refinement was asked for) and `min_edge_length`
#' @export
#' @examples
#' r <- lari_triangulate(c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2, 3, 4, 1), max_area = 0.05)
#' str(r)
lari_triangulate <- function(x, y, s0 = NULL, s1 = NULL, PA = NULL,
                             max_area = NULL, min_angle = NULL, min_edge_length = NULL,
                             erase = c("outer", "holes", "hull"), ...) {
  erase <- match.arg(erase)
  m <- lari_new(x, y, s0, s1, PA = PA)
  dots <- list(...)
  refining <- !is.null(max_area) || !is.null(min_angle) || !is.null(dots$size)
  unref <- NULL
  if (refining) {
    if (is.null(min_edge_length)) {
      min_edge_length <- default_min_edge_length(x, y, s0, s1, max_area)
    }
    unref <- lari_refine(m, min_angle = min_angle, max_area = max_area,
                         min_edge_length = min_edge_length, erase = erase, ...)
  } else {
    min_edge_length <- 0
  }
  out <- lari_tables(m, erase)
  out$unrefined <- unref
  out$min_edge_length <- min_edge_length
  out$ids <- attr(m, "ids")
  out
}

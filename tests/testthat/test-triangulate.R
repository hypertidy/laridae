## ported from cdtr tests/testthat/test-triangulate.R where the contract overlaps

test_that("constrained triangulation keeps segments and classifies depth", {
  d <- sq()
  r <- lari_triangulate(d$x, d$y, d$s0, d$s1)
  expect_equal(nrow(r$vertices), 8L)
  expect_equal(nrow(r$segments), 8L)
  ## outer erase keeps the hole triangles (depth 2) and the ring (depth 1)
  expect_setequal(unique(r$triangles$depth), c(1L, 2L))
  a <- tri_area(r$vertices, r$triangles)
  expect_equal(sum(a), 1)
  expect_equal(sum(a[r$triangles$depth == 1L]), 1 - 0.25)
  ## all fixed edges appear as triangle edges
  T <- r$triangles
  tri_edges <- edge_key(c(T$v0, T$v1, T$v2), c(T$v1, T$v2, T$v0))
  expect_true(all(edge_key(r$segments$v0, r$segments$v1) %in% tri_edges))
  ## and each maps back to its input segment
  expect_setequal(r$segments$segment, 1:8)
})

test_that("erase modes differ as expected", {
  d <- sq()
  holes <- lari_triangulate(d$x, d$y, d$s0, d$s1, erase = "holes")
  expect_true(all(holes$triangles$depth == 1L))
  expect_equal(sum(tri_area(holes$vertices, holes$triangles)), 0.75)
  hull <- lari_triangulate(d$x, d$y, d$s0, d$s1, erase = "hull")
  expect_equal(sum(tri_area(hull$vertices, hull$triangles)), 1)
})

test_that("tables carry a one-row provenance report", {
  d <- sq()
  r <- lari_triangulate(d$x, d$y, d$s0, d$s1, max_area = 0.01, erase = "outer")
  rep <- r$report
  expect_s3_class(rep, "data.frame")
  expect_equal(nrow(rep), 1L)
  expect_equal(rep$backend, "laridae")
  expect_equal(rep$erase, "outer")
  expect_true(rep$refined)
  expect_equal(rep$min_edge_length, r$min_edge_length)
  expect_match(rep$cgal, "^[0-9]")          # a version like 6.1
  expect_false(is.na(rep$bad))              # unrefined counts present when refined
  ## a handle that was never refined: report present, counts NA
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  rep0 <- lari_tables(m)$report
  expect_false(rep0$refined)
  expect_true(is.na(rep0$min_edge_length))
  expect_true(is.na(rep0$bad))
  expect_equal(rep0$backend, "laridae")
})

test_that("depth_distinct counts a doubled boundary once", {
  ## outer ring plus an inner ring given twice (a doubled boundary)
  x <- c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25)
  y <- c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75)
  s0 <- c(1, 2, 3, 4, 5, 6, 7, 8, 5, 6, 7, 8)
  s1 <- c(2, 3, 4, 1, 6, 7, 8, 5, 6, 7, 8, 5)
  r <- lari_triangulate(x, y, s0, s1, erase = "hull")
  expect_true("depth_distinct" %in% names(r$triangles))
  cx <- (r$vertices$x[r$triangles$v0] + r$vertices$x[r$triangles$v1] + r$vertices$x[r$triangles$v2]) / 3
  cy <- (r$vertices$y[r$triangles$v0] + r$vertices$y[r$triangles$v1] + r$vertices$y[r$triangles$v2]) / 3
  inner <- cx > 0.25 & cx < 0.75 & cy > 0.25 & cy < 0.75
  ## inside the doubled inner ring: weighted depth counts it twice, distinct once
  expect_equal(unique(r$triangles$depth[inner]), 3L)
  expect_equal(unique(r$triangles$depth_distinct[inner]), 2L)
  ## the annulus is depth 1 either way
  expect_equal(unique(r$triangles$depth[!inner]), 1L)
  expect_equal(unique(r$triangles$depth_distinct[!inner]), 1L)
  expect_true(all(r$triangles$depth_distinct <= r$triangles$depth))
})

test_that("area refinement honours the bound and reports min_edge_length", {
  d <- sq()
  r <- lari_triangulate(d$x, d$y, d$s0, d$s1, max_area = 0.01)
  expect_true(all(tri_area(r$vertices, r$triangles) <= 0.01 + 1e-12))
  expect_gt(nrow(r$vertices), 8L)
  expect_equal(sum(r$vertices$origin == "input"), 8L)
  expect_s3_class(r$unrefined, "data.frame")
  expect_equal(r$unrefined$bad, 0L)
  ## default floor: min(0.3 * median segment length (0.75), 0.25 * sqrt(max_area))
  expect_equal(r$min_edge_length, 0.25 * sqrt(0.01))
  expect_equal(lari_triangulate(d$x, d$y, d$s0, d$s1, min_angle = 20)$min_edge_length, 0.3 * 0.75)
  expect_equal(lari_triangulate(d$x, d$y, max_area = 0.01)$min_edge_length, 0.25 * sqrt(0.01))
  r0 <- lari_triangulate(d$x, d$y, d$s0, d$s1, max_area = 0.01, min_edge_length = 0)
  expect_equal(r0$min_edge_length, 0)
  ## the handle computes the same default from its input segments
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  expect_equal(lari_refine(m, max_area = 0.01)$min_edge_length, 0.25 * sqrt(0.01))
  expect_equal(lari_refine(m, min_angle = 20)$min_edge_length, 0.3 * 0.75)
})

test_that("angle refinement reaches the bound away from the floor", {
  d <- sq()
  r <- lari_triangulate(d$x, d$y, d$s0, d$s1, max_area = 0.01, min_angle = 25)
  V <- r$vertices; T <- r$triangles
  ang <- function(p, q, s) {
    u <- cbind(V$x[q] - V$x[p], V$y[q] - V$y[p]); w <- cbind(V$x[s] - V$x[p], V$y[s] - V$y[p])
    acos(pmax(-1, pmin(1, rowSums(u * w) / sqrt(rowSums(u^2) * rowSums(w^2))))) * 180 / pi
  }
  mn <- pmin(ang(T$v0, T$v1, T$v2), ang(T$v1, T$v2, T$v0), ang(T$v2, T$v0, T$v1))
  expect_gte(min(mn), 25 - 1e-6)
})

test_that("no refinement gives no unrefined report and zero floor", {
  d <- sq()
  r <- lari_triangulate(d$x, d$y, d$s0, d$s1)
  expect_null(r$unrefined)
  expect_equal(r$min_edge_length, 0)
})

test_that("duplicate input vertices are removed and mapped", {
  r <- lari_triangulate(c(0, 1, 0, 1, 0), c(0, 0, 1, 1, 0))
  expect_equal(nrow(r$vertices), 4L)
  expect_equal(r$ids, c(1L, 2L, 3L, 4L, 1L))
})

test_that("crossing constraints are resolved by inserting the crossing", {
  r <- lari_triangulate(c(0, 1, 0, 1), c(0, 1, 1, 0), c(1, 3), c(2, 4))
  expect_equal(nrow(r$vertices), 5L)
  expect_equal(r$vertices$origin[5], "crossing")
  expect_equal(c(r$vertices$x[5], r$vertices$y[5]), c(0.5, 0.5))
  ## four constraint edges, two from each input segment
  expect_equal(nrow(r$segments), 4L)
  expect_equal(as.vector(table(r$segments$segment)), c(2L, 2L))
})

test_that("coincident segments count once each in depth", {
  ## two unit squares sharing an edge, each ring given in full
  x <- c(0, 1, 1, 0, 2, 2); y <- c(0, 0, 1, 1, 0, 1)
  s0 <- c(1, 2, 3, 4, 2, 5, 6, 3); s1 <- c(2, 3, 4, 1, 5, 6, 3, 2)
  m <- lari_new(x, y, s0, s1)
  s <- lari_segments(m)
  expect_equal(max(s$count), 2L)
  expect_setequal(unique(lari_depth(m)), 1L)
})

test_that("no constraints falls back to the hull", {
  set.seed(1); x <- runif(30); y <- runif(30)
  expect_gt(nrow(lari_triangulate(x, y)$triangles), 0L)
  expect_equal(lari_triangulate(x, y)$triangles, lari_triangulate(x, y, erase = "hull")$triangles)
  ## and refining the hull terminates with the bound honoured
  r <- lari_triangulate(x, y, max_area = 0.005)
  expect_true(all(tri_area(r$vertices, r$triangles) <= 0.005 + 1e-12))
})

test_that("attributes are carried onto Steiner vertices by linear interpolation", {
  x <- c(0, 1, 1, 0); y <- c(0, 0, 1, 1)
  s0 <- 1:4; s1 <- c(2, 3, 4, 1)
  ## z is a linear field, so interpolation must reproduce it exactly
  z <- 2 * x + 3 * y + 1
  r <- lari_triangulate(x, y, s0, s1, PA = cbind(z_ = z), max_area = 0.02)
  V <- r$vertices
  expect_gt(nrow(V), 4L)
  expect_true("z_" %in% names(V))
  expect_equal(V$z_, 2 * V$x + 3 * V$y + 1)
  ## input rows unchanged, two columns fine
  r2 <- lari_triangulate(x, y, s0, s1, PA = cbind(z_ = z, m_ = -z), max_area = 0.02)
  expect_equal(r2$vertices$m_[1:4], -z)
  expect_equal(r2$vertices$m_, -r2$vertices$z_)
  ## zero-column PA passes through
  r00 <- lari_triangulate(x, y, s0, s1, PA = matrix(0, 4, 0), max_area = 0.02)
  expect_equal(names(r00$vertices), c("x", "y", "origin", "id"))
  ## no refinement: PA is just the input
  r0 <- lari_triangulate(x, y, s0, s1, PA = cbind(z_ = z))
  expect_equal(r0$vertices$z_, z)
})

test_that("hull-edge Steiner points get interpolated, not nearest, attributes", {
  ## At map scale, Steiner points the mesher puts on convex-hull edges land
  ## ~1e-10 outside the pre-refine hull, so locate() returns the infinite face.
  ## The old nearest-vertex fallback snapped their attributes to one endpoint;
  ## a linear field must instead be reproduced along the edge.
  set.seed(4127)
  n <- 60
  x <- runif(n) * 1e5 + 3e5
  y <- runif(n) * 1e5 + 5.2e6
  z <- x + 2 * y
  r <- lari_triangulate(x, y, PA = cbind(z_ = z),
                        max_area = 4e7, min_angle = 25, erase = "hull")
  V <- r$vertices
  expect_gt(sum(V$origin == "steiner"), 0L)
  ## relative error, since z ~ 1e7 carries ~1e-9 of absolute rounding
  rel <- abs(V$z_ - (V$x + 2 * V$y)) / max(abs(z))
  expect_lt(max(rel), 1e-12)
})

test_that("crossings get interpolated attributes", {
  x <- c(0, 1, 0, 1); y <- c(0, 1, 1, 0)
  ## consistent along both segments
  r <- lari_triangulate(x, y, c(1, 3), c(2, 4), PA = cbind(z_ = x + y))
  expect_equal(r$vertices$z_[5], 1)
  ## inconsistent: the mean of the two segments' interpolations
  r <- lari_triangulate(x, y, c(1, 3), c(2, 4), PA = cbind(z_ = c(0, 2, 5, 5)))
  expect_equal(r$vertices$z_[5], (1 + 5) / 2)
})

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

test_that("crossings get interpolated attributes", {
  x <- c(0, 1, 0, 1); y <- c(0, 1, 1, 0)
  ## consistent along both segments
  r <- lari_triangulate(x, y, c(1, 3), c(2, 4), PA = cbind(z_ = x + y))
  expect_equal(r$vertices$z_[5], 1)
  ## inconsistent: the mean of the two segments' interpolations
  r <- lari_triangulate(x, y, c(1, 3), c(2, 4), PA = cbind(z_ = c(0, 2, 5, 5)))
  expect_equal(r$vertices$z_[5], (1 + 5) / 2)
})

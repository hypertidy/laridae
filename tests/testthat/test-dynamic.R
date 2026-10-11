test_that("incremental equals batch", {
  set.seed(42)
  x <- runif(60); y <- runif(60)
  ## a closed ring through the first 8 points sorted by angle about the centre
  ring <- order(atan2(y[1:8] - 0.5, x[1:8] - 0.5))
  s0 <- ring; s1 <- c(ring[-1], ring[1])
  batch <- lari_new(x, y, s0, s1)
  inc <- lari_new()
  ids <- integer(0)
  for (i in seq_along(x)) ids <- c(ids, lari_add_points(inc, x[i], y[i]))
  for (k in seq_along(s0)) lari_add_segments(inc, ids[s0[k]], ids[s1[k]])
  for (erase in c("hull", "outer")) {
    b <- lari_tables(batch, erase); i <- lari_tables(inc, erase)
    expect_equal(tri_keys(i$vertices, i$triangles), tri_keys(b$vertices, b$triangles))
    expect_equal(sort(i$triangles$depth), sort(b$triangles$depth))
  }
})

test_that("add then remove is a no-op on the tables", {
  d <- sq()
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  before <- lari_tables(m, "hull")
  ## points
  ids <- lari_add_points(m, c(0.1, 0.9, 0.5), c(0.1, 0.2, 0.9))
  expect_equal(nrow(lari_vertices(m)), 11L)
  lari_remove_points(m, ids)
  after <- lari_tables(m, "hull")
  expect_equal(after$vertices, before$vertices)
  expect_equal(tri_keys(after$vertices, after$triangles), tri_keys(before$vertices, before$triangles))
  ## a segment that crosses the hole ring twice
  p <- lari_add_points(m, c(0.1, 0.9), c(0.5, 0.5))
  sid <- lari_add_segments(m, p[1], p[2])
  expect_equal(sum(lari_vertices(m)$origin == "crossing"), 2L)
  lari_remove_segments(m, p[1], p[2])
  lari_remove_points(m, p)
  after <- lari_tables(m, "hull")
  expect_equal(after$vertices, before$vertices)
  expect_equal(after$segments[order(after$segments$segment), ],
               before$segments[order(before$segments$segment), ], ignore_attr = TRUE)
  expect_equal(tri_keys(after$vertices, after$triangles), tri_keys(before$vertices, before$triangles))
  ## by segment id
  p <- lari_add_points(m, c(0.5, 0.5), c(0.1, 0.9))
  sid <- lari_add_segments(m, p[1], p[2])
  lari_remove_segments(m, id = sid)
  lari_remove_points(m, p)
  expect_equal(lari_vertices(m), before$vertices)
})

test_that("ids are stable across removals", {
  m <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1))
  a <- lari_add_points(m, 0.5, 0.5)
  lari_remove_points(m, 2)
  b <- lari_add_points(m, 0.25, 0.75)
  expect_equal(a, 5L)
  expect_equal(b, 6L)
  v <- lari_vertices(m)
  expect_equal(v$id, c(1L, 3L, 4L, 5L, 6L))
  expect_error(lari_remove_points(m, 2), "not in the mesh")
})

test_that("removing a point drops the segments that end there", {
  d <- sq()
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  lari_remove_points(m, 5)
  s <- lari_segments(m)
  expect_equal(nrow(s), 6L)
  expect_false(any(s$segment %in% c(4L + 1L, 8L)))
})

test_that("a second refine after a small edit touches only its neighbourhood", {
  x <- c(0, 1, 1, 0); y <- c(0, 0, 1, 1)
  m <- lari_new(x, y, 1:4, c(2, 3, 4, 1))
  lari_refine(m, max_area = 0.002, min_angle = 25)
  v0 <- lari_vertices(m)
  ## a short new constraint near one corner
  p <- lari_add_points(m, c(0.1, 0.13), c(0.1, 0.12))
  lari_add_segments(m, p[1], p[2])
  expect_false(lari_counts(m)$mesher_alive)
  lari_refine(m, max_area = 0.002, min_angle = 25)
  v1 <- lari_vertices(m)
  ## nothing old moved or went away
  expect_true(all(v0$id %in% v1$id))
  new <- v1[!v1$id %in% c(v0$id, p), ]
  expect_lt(nrow(new), 0.2 * nrow(v0))
  if (nrow(new) > 0L) {
    expect_lt(max(sqrt((new$x - 0.115)^2 + (new$y - 0.11)^2)), 0.3)
  }
})

test_that("step refines one point at a time and matches a full refine", {
  d <- sq()
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  lari_refine(m, max_area = 0.01, max_steiner = 0)
  expect_equal(lari_counts(m)$steiner, 0L)
  expect_equal(lari_counts(m)$unrefined[["budgetHit"]], 1L)
  n1 <- lari_step(m, 1)
  expect_equal(n1, 1L)
  n <- 0L
  repeat {
    k <- lari_step(m, 50)
    n <- n + k
    if (k == 0L) break
  }
  full <- lari_new(d$x, d$y, d$s0, d$s1)
  lari_refine(full, max_area = 0.01)
  expect_equal(lari_counts(m)$steiner, lari_counts(full)$steiner)
  expect_true(all(tri_area(lari_vertices(m), lari_triangles(m)) <= 0.01 + 1e-12))
  ## max_steiner caps a refine
  b <- lari_new(d$x, d$y, d$s0, d$s1)
  lari_refine(b, max_area = 0.001, max_steiner = 10)
  expect_equal(lari_counts(b)$steiner, 10L)
})

test_that("step after an edit rebuilds the mesher on the edited mesh", {
  d <- sq()
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  lari_refine(m, max_area = 0.01)
  n0 <- nrow(lari_vertices(m))
  lari_add_points(m, 0.05, 0.95)
  repeat if (lari_step(m, 100) == 0L) break
  expect_true(all(tri_area(lari_vertices(m), lari_triangles(m)) <= 0.01 + 1e-12))
  expect_error(lari_step(lari_new(c(0, 1, 0), c(0, 0, 1))), "lari_refine")
})

test_that("seeds mark regions that are not meshed", {
  d <- sq()
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  lari_refine(m, max_area = 0.005, seeds = cbind(0.5, 0.5))
  T <- lari_triangles(m)
  a <- tri_area(lari_vertices(m), T)
  expect_true(all(a[T$depth == 1L] <= 0.005 + 1e-12))
  expect_true(any(a[T$depth == 2L] > 0.005))
  ## erase = "holes" does the same from depth
  h <- lari_new(d$x, d$y, d$s0, d$s1)
  lari_refine(h, max_area = 0.005, erase = "holes")
  T <- lari_triangles(h)
  expect_true(any(tri_area(lari_vertices(h), T)[T$depth == 2L] > 0.005))
})

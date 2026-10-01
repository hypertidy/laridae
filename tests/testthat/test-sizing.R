test_that("a sizing function produces the expected area gradient", {
  x <- c(0, 1, 1, 0); y <- c(0, 0, 1, 1)
  m <- lari_new(x, y, 1:4, c(2, 3, 4, 1))
  size <- function(x, y) 0.0005 + 0.01 * x
  lari_refine(m, size = size, min_edge_length = 0)
  V <- lari_vertices(m); T <- lari_triangles(m)
  a <- tri_area(V, T); cen <- centroids(V, T)
  ## every triangle within its local bound
  expect_true(all(a <= size(cen[, "x"], cen[, "y"]) * (1 + 1e-9)))
  ## and area grows with x
  left <- mean(a[cen[, "x"] < 0.25]); right <- mean(a[cen[, "x"] > 0.75])
  expect_gt(right / left, 3)
  expect_gt(cor(cen[, "x"], a), 0.5)
})

test_that("a sizing grid works and combines with max_area", {
  x <- c(0, 1, 1, 0); y <- c(0, 0, 1, 1)
  g <- list(x = seq(0.05, 0.95, by = 0.1), y = seq(0.05, 0.95, by = 0.1))
  g$z <- outer(g$x, g$y, function(x, y) ifelse(y < 0.5, 0.0005, 0.05))
  m <- lari_new(x, y, 1:4, c(2, 3, 4, 1))
  lari_refine(m, size = g, max_area = 0.01, min_edge_length = 0)
  V <- lari_vertices(m); T <- lari_triangles(m)
  a <- tri_area(V, T); cen <- centroids(V, T)
  expect_true(all(a <= 0.01 + 1e-12))
  expect_true(all(a[cen[, "y"] < 0.45] <= 0.0005 * (1 + 1e-9)))
  expect_gt(mean(a[cen[, "y"] > 0.55]), 5 * mean(a[cen[, "y"] < 0.45]))
  expect_error(lari_refine(m, size = list(x = 1:2, y = 1:3, z = 1)), "length")
})

test_that("refine needs a criterion", {
  m <- lari_new(c(0, 1, 0), c(0, 0, 1))
  expect_error(lari_refine(m), "at least one")
})

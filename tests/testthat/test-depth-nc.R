nc_rings <- function() {
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  rings <- unlist(lapply(sf::st_geometry(nc), function(g) lapply(unclass(g), `[[`, 1)), recursive = FALSE)
  xy <- do.call(rbind, lapply(rings, function(m) m[-nrow(m), ]))
  n <- vapply(rings, function(m) nrow(m) - 1L, 1L)
  start <- rep(cumsum(c(0L, n[-length(n)])), n)
  s0 <- seq_along(xy[, 1])
  s1 <- start + (s0 - start) %% rep(n, n) + 1L
  list(x = xy[, 1], y = xy[, 2], s0 = s0, s1 = s1)
}

test_that("nc counties give depths 1, 3, 5", {
  skip_if_not_installed("sf")
  d <- nc_rings()
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  expect_equal(sort(unique(lari_depth(m))), c(1L, 3L, 5L))
})

test_that("depth matches cdtr on identical input", {
  skip_if_not_installed("sf")
  skip_if_not_installed("cdtr")
  d <- nc_rings()
  l <- lari_triangulate(d$x, d$y, d$s0, d$s1)
  r <- cdtr::cdt_triangulate(d$x, d$y, d$s0, d$s1)
  expect_equal(nrow(l$triangles), nrow(r$T))
  expect_equal(table(l$triangles$depth), table(r$depth), ignore_attr = TRUE)
})

test_that("refining the hull leaves no flat triangles along it", {
  skip_if_not_installed("sf")
  d <- nc_rings()
  A <- diff(range(d$x)) * diff(range(d$y))
  r <- lari_triangulate(d$x, d$y, d$s0, d$s1, max_area = A / 5000, erase = "hull")
  a <- tri_area(r$vertices, r$triangles)
  expect_true(all(a <= A / 5000 * (1 + 1e-9)))
  expect_gt(min(a), 1e-6 * stats::median(a))
  ## the output still covers the convex hull of the input
  h <- chull(d$x, d$y)
  hull_area <- abs(sum(d$x[h] * d$y[c(h[-1], h[1])] - d$x[c(h[-1], h[1])] * d$y[h])) / 2
  expect_equal(sum(a), hull_area, tolerance = 1e-9)
  expect_equal(r$unrefined$stalled, 0L)
})

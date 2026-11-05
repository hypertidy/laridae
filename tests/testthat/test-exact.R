test_that("exact crossings come back as rationals", {
  x <- c(0, 3, 0, 1); y <- c(0, 1, 1, 0)
  r <- lari_cdt(x, y, c(1, 3), c(2, 4), exact = TRUE)
  v <- r$vertices[r$vertices$origin == "crossing", ]
  expect_equal(nrow(v), 1L)
  expect_identical(c(v$x_num, v$x_den, v$y_num, v$y_den), c("3", "4", "1", "4"))
  expect_equal(nrow(r$triangles), 4L)
})

test_that("medians meet in one exact vertex at (1/3, 1/3)", {
  x <- c(0, 1, 0, 0.5, 0, 0.5); y <- c(0, 0, 1, 0.5, 0.5, 0)
  r <- lari_cdt(x, y, 1:3, 4:6, exact = TRUE)
  v <- r$vertices[r$vertices$origin == "crossing", ]
  expect_equal(nrow(v), 1L)
  expect_identical(c(v$x_num, v$x_den), c("1", "3"))
})

test_that("inexact run leaves the rational columns NA", {
  r <- lari_cdt(c(0, 3, 0, 1), c(0, 1, 1, 0), c(1, 3), c(2, 4), exact = FALSE)
  expect_true(all(is.na(r$vertices$x_num)))
})

test_that("exact vertices come back as the nearest double", {
  # integer segments on a small grid: every crossing is a rational whose
  # numerator and denominator are exact in double, so their quotient is the
  # correctly rounded value
  set.seed(1)
  n <- 60
  x <- sample(0:12, 2 * n, TRUE); y <- sample(0:12, 2 * n, TRUE)
  s0 <- seq(1, 2 * n, 2); s1 <- s0 + 1
  keep <- !(x[s0] == x[s1] & y[s0] == y[s1]); s0 <- s0[keep]; s1 <- s1[keep]
  v <- lari_cdt(x, y, s0, s1, exact = TRUE)$vertices
  expect_gt(sum(v$origin == "crossing"), 100L)
  expect_identical(v$x, as.numeric(v$x_num) / as.numeric(v$x_den))
  expect_identical(v$y, as.numeric(v$y_num) / as.numeric(v$y_den))
})

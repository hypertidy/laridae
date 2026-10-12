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

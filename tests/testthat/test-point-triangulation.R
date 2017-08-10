context("point-triangulation")
x <- c(0, 0, 1, 1)
y <- c(0, 1, 1, 0)

## triplet index triangulation of x,y
prim3_index <-
  c(4, 3, 2,
    4, 2, 1)
## native vertex order (not much use out here)
vert_index <- c(2, 3, 1, 4, 1, 1)

test_that("simple triangulation works", {
  expect_equal(tri_xy(x, y) + 1, prim3_index)
  expect_equal(tri_xy2(x, y) + 1, prim3_index)

  expect_equal(tri_xy1(x, y) + 1, vert_index)

})

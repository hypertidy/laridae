## rings in, letters out: lari_glyphs() needs no font packages

square_o <- function(close = FALSE) {
  x <- c(0, 1, 1, 0, 0.3, 0.3, 0.7, 0.7)
  y <- c(0, 0, 1, 1, 0.3, 0.7, 0.7, 0.3)
  d <- data.frame(x = x, y = y, glyph = 1L, ring = rep(1:2, each = 4))
  if (close) d <- d[c(1:4, 1, 5:8, 5), ]
  d
}

test_that("a counter is a hole whatever the ring orientation", {
  d <- square_o()
  r <- lari_glyphs(d)
  expect_true(all(r$triangles$depth == 1L))
  expect_equal(sum(tri_area(r$vertices, r$triangles)), 1 - 0.16)
  ## reverse the outer ring: same letter
  d2 <- d
  d2[1:4, ] <- d2[4:1, ]
  expect_equal(sum(tri_area(lari_glyphs(d2)$vertices, lari_glyphs(d2)$triangles)), 1 - 0.16)
  ## outer keeps the counter, at depth 2
  o <- lari_glyphs(d, erase = "outer")
  expect_equal(sum(tri_area(o$vertices, o$triangles)), 1)
  expect_setequal(unique(o$triangles$depth), 1:2)
})

test_that("closed rings, other column names and refinement", {
  a <- lari_glyphs(square_o())
  b <- lari_glyphs(square_o(close = TRUE))
  expect_equal(nrow(a$vertices), nrow(b$vertices))
  expect_equal(nrow(a$segments), 8L)
  ## string2path and systemfonts::glyph_outline names
  d <- square_o(close = TRUE)
  names(d) <- c("x", "y", "glyph_id", "path_id")
  expect_equal(nrow(lari_glyphs(d)$segments), 8L)
  names(d) <- c("x", "y", "glyph", "contour")
  expect_equal(nrow(lari_glyphs(d)$segments), 8L)
  r <- lari_glyphs(square_o(), max_area = 0.005, min_angle = 25)
  expect_true(all(tri_area(r$vertices, r$triangles) <= 0.005 + 1e-12))
  expect_equal(sum(tri_area(r$vertices, r$triangles)), 1 - 0.16)
})

test_that("glyphs bind into one set of tables, or merge into one mesh", {
  d1 <- square_o()
  d2 <- square_o()
  d2$x <- d2$x + 1.5
  d2$glyph <- 2L
  d <- rbind(d1, d2)
  r <- lari_glyphs(d)
  expect_equal(nrow(r$report), 2L)
  expect_setequal(r$triangles$glyph, 1:2)
  ## per-glyph row offsets: every triangle of glyph 2 uses glyph 2 vertices
  T2 <- r$triangles[r$triangles$glyph == 2L, ]
  expect_true(all(r$vertices$glyph[c(T2$v0, T2$v1, T2$v2)] == 2L))
  expect_equal(sort(r$segments$segment), 1:16)
  m <- lari_glyphs(d, merge = TRUE)
  expect_equal(nrow(m$report), 1L)
  expect_equal(sum(tri_area(m$vertices, m$triangles)), 2 * (1 - 0.16))
  expect_equal(table(m$segments$glyph)[["2"]], 8L)
  expect_true(all(is.na(m$triangles$glyph)))
  ## overlapping glyphs merged: the overlap has even depth and is erased
  d3 <- d1
  d3$x <- d3$x + 0.5
  d3$glyph <- 2L
  x <- lari_glyphs(rbind(d1, d3), merge = TRUE, erase = "hull")
  expect_true(max(x$triangles$depth) >= 2L)
})

test_that("bad outlines are refused", {
  expect_error(lari_glyphs(list(x = 1)), "data frame")
  expect_error(lari_glyphs(data.frame(a = 1)), "'x' and 'y'")
  expect_error(lari_glyphs(square_o()[0, ]), "no outline")
})

test_that("text is shaped, outlined and meshed", {
  skip_if_not_installed("systemfonts", "1.2.0")
  skip_if_not_installed("textshaping")
  o <- lari_text_outline("AB")
  expect_named(o, c("x", "y", "glyph", "ring", "char"))
  expect_equal(unique(o$char), c("A", "B"))
  ## A has one counter, B two
  expect_equal(as.vector(tapply(o$ring, o$glyph, max)), c(2L, 3L))
  r <- lari_text("AB", max_area = 0.002)
  expect_setequal(r$triangles$char, c("A", "B"))
  expect_true(all(r$triangles$depth == 1L))
  ## mesh area equals the parity area of the rings
  ring_area <- function(d) {
    j <- c(seq_len(nrow(d))[-1L], 1L)
    sum(d$x * d$y[j] - d$x[j] * d$y) / 2
  }
  ra <- vapply(split(o, paste(o$glyph, o$ring)), ring_area, numeric(1))
  expect_equal(sum(tri_area(r$vertices, r$triangles)), abs(sum(ra)), tolerance = 1e-9)
  ## em scales coordinates
  o2 <- lari_text_outline("AB", em = 10)
  expect_equal(diff(range(o2$y)), 10 * diff(range(o$y)), tolerance = 1e-3)
  ## a sizing field passes through to the refiner
  s <- lari_text("AB", size = function(x, y) 1e-4 + 0.01 * x)
  expect_gt(nrow(s$triangles), nrow(lari_text("AB")$triangles))
  ## whitespace has no outline
  expect_equal(length(unique(lari_text_outline("A B")$glyph)), 2L)
})

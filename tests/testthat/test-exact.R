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

## rectangles as CCW rings: one row per rectangle (xmin, ymin, xmax, ymax)
exact_rects <- function(b) {
  x <- y <- s0 <- s1 <- numeric(0)
  for (i in seq_len(nrow(b))) {
    o <- length(x)
    x <- c(x, b[i, 1], b[i, 3], b[i, 3], b[i, 1])
    y <- c(y, b[i, 2], b[i, 2], b[i, 4], b[i, 4])
    s0 <- c(s0, o + 1:4)
    s1 <- c(s1, o + c(2:4, 1))
  }
  list(x = x, y = y, s0 = s0, s1 = s1)
}

## total winding per triangle from edge_sources alone (spec Annex A)
exact_winding <- function(r) {
  t <- r$triangles; s <- r$segments; es <- r$edge_sources
  nt <- nrow(t)
  a <- c(t$v0, t$v1, t$v2); b <- c(t$v1, t$v2, t$v0)
  tri <- rep(seq_len(nt), 3L)
  twin <- match(paste(b, a), paste(a, b))
  edge <- match(paste(pmin(a, b), pmax(a, b)), paste(s$v0, s$v1))
  step <- function(i) {
    k <- edge[i]
    if (is.na(k)) return(0)
    f <- es$forward[es$edge == k]
    -sum(ifelse(f == (a[i] == s$v0[k]), 1, -1))
  }
  w <- rep(NA_real_, nt); bad <- 0L
  for (start in which(is.na(twin))) {
    if (!is.na(w[tri[start]])) next
    w[tri[start]] <- -step(start)
    queue <- tri[start]
    while (length(queue)) {
      tt <- queue[1]; queue <- queue[-1]
      for (i in which(tri == tt)) {
        if (is.na(twin[i])) { if (w[tt] != -step(i)) bad <- bad + 1L; next }
        u <- tri[twin[i]]; wu <- w[tt] + step(i)
        if (is.na(w[u])) { w[u] <- wu; queue <- c(queue, u) } else if (w[u] != wu) bad <- bad + 1L
      }
    }
  }
  attr(w, "inconsistent") <- bad
  w
}

test_that("lari_cdt returns depth, segment provenance and edge_sources on both kernels", {
  ## four bars around a gap, plus an offset square crossing all of them
  b <- rbind(c(0, 0, 3, 1), c(0, 2, 3, 3), c(0, 0, 1, 3), c(2, 0, 3, 3),
             c(0.1, 0.3, 2.9, 2.7) + c(1, 1, 1, 1) / 7)
  d <- exact_rects(b)
  for (exact in c(TRUE, FALSE)) {
    r <- lari_cdt(d$x, d$y, d$s0, d$s1, exact = exact, erase = "outer")
    es <- r$edge_sources; s <- r$segments; v <- r$vertices; t <- r$triangles
    expect_named(es, c("edge", "segment", "forward"))
    expect_setequal(es$edge, seq_len(nrow(s)))
    expect_setequal(es$segment, seq_along(d$s0))
    expect_identical(order(es$edge, es$segment), seq_len(nrow(es)))
    expect_identical(s$count, tabulate(es$edge, nrow(s)))
    expect_identical(s$segment, as.integer(tapply(es$segment, es$edge, min)))
    expect_true(all(s$v0 < s$v1))
    ## forward agrees with the coordinates
    dv <- cbind(v$x[s$v1[es$edge]] - v$x[s$v0[es$edge]], v$y[s$v1[es$edge]] - v$y[s$v0[es$edge]])
    ov <- cbind(d$x[d$s1[es$segment]] - d$x[d$s0[es$segment]],
                d$y[d$s1[es$segment]] - d$y[d$s0[es$segment]])
    expect_identical(rowSums(dv * ov) > 0, es$forward)
    ## triangles counter-clockwise, all inside (outer erase)
    ar <- (v$x[t$v1] - v$x[t$v0]) * (v$y[t$v2] - v$y[t$v0]) -
      (v$x[t$v2] - v$x[t$v0]) * (v$y[t$v1] - v$y[t$v0])
    expect_true(all(ar > 0))
    expect_true(all(t$depth > 0))
    expect_true(all(t$depth_distinct <= t$depth))
    ## winding from edge_sources is the overlap count, consistent everywhere
    w <- exact_winding(r)
    expect_identical(attr(w, "inconsistent"), 0L)
    cx <- (v$x[t$v0] + v$x[t$v1] + v$x[t$v2]) / 3
    cy <- (v$y[t$v0] + v$y[t$v1] + v$y[t$v2]) / 3
    count <- rowSums(outer(cx, b[, 1], ">") & outer(cx, b[, 3], "<") &
                       outer(cy, b[, 2], ">") & outer(cy, b[, 4], "<"))
    expect_equal(as.vector(w), count)
  }
})

test_that("lari_cdt agrees with the handle on depth and edge_sources", {
  d <- exact_rects(rbind(c(0, 0, 2, 2), c(1, 1, 3, 3), c(0, 0, 2, 2)))
  for (erase in c("outer", "hull", "holes")) {
    a <- lari_cdt(d$x, d$y, d$s0, d$s1, exact = TRUE, erase = erase)
    h <- lari_triangulate(d$x, d$y, d$s0, d$s1, erase = erase)
    ## same mesh, keyed on coordinates
    key_t <- function(r) {
      v <- r$vertices; t <- r$triangles
      k <- paste(v$x, v$y)
      sort(paste(apply(cbind(k[t$v0], k[t$v1], k[t$v2]), 1, function(z) paste(sort(z), collapse = "|")),
                 t$depth, t$depth_distinct))
    }
    expect_identical(key_t(a), key_t(h))
    key_e <- function(r) {
      v <- r$vertices; s <- r$segments[r$edge_sources$edge, ]
      p0 <- paste(v$x[s$v0], v$y[s$v0]); p1 <- paste(v$x[s$v1], v$y[s$v1])
      lo <- pmin(p0, p1); fw <- ifelse(p0 == lo, r$edge_sources$forward, !r$edge_sources$forward)
      sort(paste(lo, pmax(p0, p1), r$edge_sources$segment, fw))
    }
    expect_identical(key_e(a), key_e(h))
  }
})

test_that("zero-length segments make no constraint", {
  r <- lari_cdt(c(0, 1, 1, 0), c(0, 0, 1, 1), c(1:4, 2), c(2:4, 1, 2), erase = "outer")
  expect_false(5L %in% r$edge_sources$segment)
  expect_equal(nrow(r$segments), 4L)
})

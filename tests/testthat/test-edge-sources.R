## mesh spec v0.2: edge_sources

## rectangles as CCW rings: one row per rectangle (xmin, ymin, xmax, ymax)
rect_rings <- function(b) {
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

## total winding of every triangle from edge_sources alone (spec Annex A):
## walk the adjacency from the mesh boundary, across each constraint edge
## adding or subtracting its sources
winding <- function(r) {
  t <- r$triangles; s <- r$segments; es <- r$edge_sources
  nt <- nrow(t)
  a <- c(t$v0, t$v1, t$v2)
  b <- c(t$v1, t$v2, t$v0)
  tri <- rep(seq_len(nt), 3L)
  twin <- match(paste(b, a), paste(a, b))
  key <- paste(pmin(s$v0, s$v1), pmax(s$v0, s$v1))
  edge <- match(paste(pmin(a, b), pmax(a, b)), key)
  ## change crossing side i from its triangle (left of a -> b) to the right
  step <- function(i) {
    k <- edge[i]
    if (is.na(k)) return(0)
    f <- es$forward[es$edge == k]
    -sum(ifelse(f == (a[i] == s$v0[k]), 1, -1))
  }
  w <- rep(NA_real_, nt)
  bad <- 0L
  for (start in which(is.na(twin))) {
    if (!is.na(w[tri[start]])) next
    w[tri[start]] <- -step(start)
    queue <- tri[start]
    while (length(queue)) {
      tt <- queue[1]; queue <- queue[-1]
      for (i in which(tri == tt)) {
        if (is.na(twin[i])) {
          if (w[tt] != -step(i)) bad <- bad + 1L
          next
        }
        u <- tri[twin[i]]
        wu <- w[tt] + step(i)
        if (is.na(w[u])) {
          w[u] <- wu
          queue <- c(queue, u)
        } else if (w[u] != wu) {
          bad <- bad + 1L
        }
      }
    }
  }
  attr(w, "inconsistent") <- bad
  w
}

expect_edge_sources <- function(r, x, y, s0, s1) {
  es <- r$edge_sources; s <- r$segments; v <- r$vertices
  expect_named(es, c("edge", "segment", "forward"))
  expect_type(es$edge, "integer")
  expect_type(es$forward, "logical")
  ## coverage and order
  expect_setequal(es$edge, seq_len(nrow(s)))
  keep <- x[s0] != x[s1] | y[s0] != y[s1]
  expect_setequal(es$segment, seq_along(s0)[keep])
  expect_identical(order(es$edge, es$segment), seq_len(nrow(es)))
  ## count and segment are derived from it
  expect_identical(s$count, tabulate(es$edge, nrow(s)))
  expect_identical(s$segment, as.integer(tapply(es$segment, es$edge, min)))
  ## direction agrees with the coordinates
  dv <- cbind(v$x[s$v1[es$edge]] - v$x[s$v0[es$edge]], v$y[s$v1[es$edge]] - v$y[s$v0[es$edge]])
  ov <- cbind(x[s1[es$segment]] - x[s0[es$segment]], y[s1[es$segment]] - y[s0[es$segment]])
  expect_identical(rowSums(dv * ov) > 0, es$forward)
}

test_that("edge_sources covers every constraint edge and input segment", {
  d <- rect_rings(rbind(c(0, 0, 2, 2), c(1, 1, 3, 3)))
  for (ma in list(NULL, 0.05)) {
    r <- lari_triangulate(d$x, d$y, d$s0, d$s1, max_area = ma)
    expect_edge_sources(r, d$x, d$y, d$s0, d$s1)
  }
  m <- lari_new(d$x, d$y, d$s0, d$s1)
  expect_identical(lari_edge_sources(m), lari_tables(m)$edge_sources)
})

test_that("a short input on a longer collinear input keeps both, through refinement", {
  ## A = (0,0)-(1,0) lies on B = (0,0)-(2,0)
  x <- c(0, 1, 2, 1); y <- c(0, 0, 0, 1)
  s0 <- c(1, 1, 3, 4); s1 <- c(2, 3, 4, 1)
  for (ma in list(NULL, 0.01)) {
    r <- lari_triangulate(x, y, s0, s1, max_area = ma)
    expect_edge_sources(r, x, y, s0, s1)
    v <- r$vertices; s <- r$segments; es <- r$edge_sources
    on0 <- which(v$y[s$v0] == 0 & v$y[s$v1] == 0)
    xm <- (v$x[s$v0[on0]] + v$x[s$v1[on0]]) / 2
    for (i in seq_along(on0)) {
      seg <- es$segment[es$edge == on0[i]]
      if (xm[i] < 1) expect_identical(seg, 1:2) else expect_identical(seg, 2L)
    }
  }
})

test_that("duplicated input segments are listed once per copy", {
  x <- c(0, 1, 1, 0); y <- c(0, 0, 1, 1)
  r <- lari_triangulate(x, y, c(1:4, 1), c(2:4, 1, 2))
  expect_equal(sort(as.vector(table(r$edge_sources$edge))), c(1L, 1L, 1L, 2L))
  ## the copy given the other way round runs backwards
  r <- lari_triangulate(x, y, c(1:4, 2), c(2:4, 1, 1))
  es <- r$edge_sources
  expect_identical(sort(es$forward[es$segment %in% c(1L, 5L)]), c(FALSE, TRUE))
})

test_that("edge_sources follows segments added and removed later", {
  d <- rect_rings(rbind(c(0, 0, 2, 2)))
  m <- lari_new(c(d$x, 1, 1), c(d$y, -1, 3), d$s0, d$s1)
  sid <- lari_add_segments(m, 5, 6)
  es <- lari_edge_sources(m)
  expect_true(all(c(1:4, sid) %in% es$segment))
  expect_equal(sum(es$segment == sid), 3L)  ## three pieces between two crossings
  lari_remove_segments(m, id = sid)
  es <- lari_edge_sources(m)
  expect_setequal(es$segment, 1:4)
})

test_that("winding from edge_sources gives the overlap count where depth does not", {
  ## four overlapping bars around an uncovered gap [1, 2] x [1, 2]
  b <- rbind(c(0, 0, 3, 1), c(0, 2, 3, 3), c(0, 0, 1, 3), c(2, 0, 3, 3))
  d <- rect_rings(b)
  for (erase in c("outer", "hull")) {
    for (ma in list(NULL, 0.05)) {
      r <- lari_triangulate(d$x, d$y, d$s0, d$s1, erase = erase, max_area = ma)
      w <- winding(r)
      expect_identical(attr(w, "inconsistent"), 0L)
      v <- r$vertices; t <- r$triangles
      cx <- (v$x[t$v0] + v$x[t$v1] + v$x[t$v2]) / 3
      cy <- (v$y[t$v0] + v$y[t$v1] + v$y[t$v2]) / 3
      count <- rowSums(outer(cx, b[, 1], ">") & outer(cx, b[, 3], "<") &
                         outer(cy, b[, 2], ">") & outer(cy, b[, 4], "<"))
      expect_equal(as.vector(w), count)
      gap <- cx > 1 & cx < 2 & cy > 1 & cy < 2
      expect_true(all(w[gap] == 0))
      expect_true(all(t$depth[gap] > 0))
    }
  }
})

test_that("edge_sources agrees with cdtr's", {
  skip_if_not_installed("cdtr")
  skip_if_not("edge_sources" %in% names(formals(cdtr::cdt_triangulate)))
  d <- rect_rings(rbind(c(0, 0, 3, 1), c(0, 2, 3, 3), c(0, 0, 1, 3), c(2, 0, 3, 3),
                        c(0.5, 0.5, 2.5, 2.5)))
  r <- lari_triangulate(d$x, d$y, d$s0, d$s1)
  k <- cdtr::cdt_triangulate(d$x, d$y, d$s0, d$s1, edge_sources = TRUE)
  ## key each row on the edge's end coordinates, v0 first
  lk <- with(r, {
    s <- segments[edge_sources$edge, ]
    paste(vertices$x[s$v0], vertices$y[s$v0], vertices$x[s$v1], vertices$y[s$v1],
          edge_sources$segment, edge_sources$forward)
  })
  ck <- with(k, {
    S <- S[edge_sources$edge, , drop = FALSE]
    a <- P[S[, 1], , drop = FALSE]; b <- P[S[, 2], , drop = FALSE]
    ## cdtr's S rows may differ in end order from laridae's (v0 by vertex row):
    ## orient both by laridae's vertex order through coordinates
    paste(a[, 1], a[, 2], b[, 1], b[, 2], edge_sources$segment, edge_sources$forward)
  })
  flip <- function(z) {
    p <- strsplit(z, " ")
    vapply(p, function(q) paste(q[3], q[4], q[1], q[2], q[5], !as.logical(q[6])), "")
  }
  expect_true(all(lk %in% c(ck, flip(ck))))
  expect_equal(length(lk), length(ck))
})

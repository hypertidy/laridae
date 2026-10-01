## unit square with a square hole: 8 vertices, two closed rings
sq <- function() {
  x <- c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25)
  y <- c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75)
  s0 <- c(1, 2, 3, 4, 5, 6, 7, 8); s1 <- c(2, 3, 4, 1, 6, 7, 8, 5)
  list(x = x, y = y, s0 = s0, s1 = s1)
}
tri_area <- function(V, T) {
  P <- cbind(V$x, V$y)
  T <- cbind(T$v0, T$v1, T$v2)
  a <- P[T[, 1], , drop = FALSE]; b <- P[T[, 2], , drop = FALSE]; c <- P[T[, 3], , drop = FALSE]
  0.5 * abs((b[, 1] - a[, 1]) * (c[, 2] - a[, 2]) - (c[, 1] - a[, 1]) * (b[, 2] - a[, 2]))
}
centroids <- function(V, T) {
  cbind(x = (V$x[T$v0] + V$x[T$v1] + V$x[T$v2]) / 3,
        y = (V$y[T$v0] + V$y[T$v1] + V$y[T$v2]) / 3)
}
## triangles as sorted coordinate keys, independent of vertex and face order
tri_keys <- function(V, T) {
  k <- paste(signif(V$x, 12), signif(V$y, 12))
  m <- cbind(k[T$v0], k[T$v1], k[T$v2])
  sort(apply(m, 1, function(r) paste(sort(r), collapse = "|")))
}
edge_key <- function(a, b) paste(pmin(a, b), pmax(a, b))

## the dynamic cases: what an edit costs against a rebuild
source(system.file("benchmarks", "helpers.R", package = "laridae"))

p <- cases$nc
A <- prod(diff(apply(p$P, 2, range)))
a <- A / 5000
build <- function() {
  m <- lari_new(p$P[, 1], p$P[, 2], p$S[, 1], p$S[, 2])
  lari_refine(m, max_area = a, min_angle = 20)
  m
}
m <- build()
k0 <- lari_counts(m)
## a small edit near the middle: a short new constraint
cx <- mean(range(p$P[, 1])); cy <- mean(range(p$P[, 2]))
ids <- lari_add_points(m, cx + c(0, 0.05), cy + c(0, 0.02))
lari_add_segments(m, ids[1], ids[2])
t_local <- system.time(lari_refine(m, max_area = a, min_angle = 20))[["elapsed"]]
k1 <- lari_counts(m)
cat("full build + refine:", system.time(build())[["elapsed"]], "s\n")
cat("re-refine after a small edit:", t_local, "s, inserted", k1$unrefined[["inserted"]],
    "of", k1$steiner, "Steiner vertices\n")

## sizing field: fine near the coast (low x), coarse inland
m <- lari_new(p$P[, 1], p$P[, 2], p$S[, 1], p$S[, 2])
x0 <- min(p$P[, 1]); w <- diff(range(p$P[, 1]))
print(system.time(lari_refine(m, size = function(x, y) a * (0.2 + 4 * ((x - x0) / w)^2), min_angle = 20)))
T <- lari_triangles(m); V <- lari_vertices(m)
cen <- (V$x[T$v0] + V$x[T$v1] + V$x[T$v2]) / 3
print(tapply(tri_area(V, T), cut(cen, 5), mean))

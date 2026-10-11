## bare-point Delaunay triangulation: laridae vs cdtr vs RTriangle
## (2026-10-01, one Linux core, seconds; laridae build + table extraction):
##   n = 1e5: laridae 0.12 + 0.03, cdtr 0.16, RTriangle 0.25
##   n = 1e6: laridae 1.35 + 0.53, cdtr 2.48, RTriangle 3.46
library(laridae)
for (n in c(1e3, 1e4, 1e5, 1e6)) {
  set.seed(90); x <- rnorm(n); y <- rnorm(n)
  t_build <- system.time(m <- lari_new(x, y))[["elapsed"]]
  t_tab <- system.time(lari_triangles(m))[["elapsed"]]
  t_cdtr <- if (requireNamespace("cdtr", quietly = TRUE)) system.time(cdtr::cdt_triangulate(x, y))[["elapsed"]] else NA
  t_rt <- if (requireNamespace("RTriangle", quietly = TRUE)) {
    system.time(RTriangle::triangulate(RTriangle::pslg(P = cbind(x, y))))[["elapsed"]]
  } else NA
  cat(sprintf("n = %7d  laridae %.3f + %.3f  cdtr %.3f  RTriangle %.3f\n", as.integer(n), t_build, t_tab, t_cdtr, t_rt))
}

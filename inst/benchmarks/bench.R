## laridae against cdtr (and RTriangle, when installed) on the shared cases.
## Reference numbers from the cdtr benchmarks, nc at a = A/5000, q = 20:
## Triangle 5 ms, cdtr 19 ms.
source(system.file("benchmarks", "helpers.R", package = "laridae"))

lari <- function(p, ...) lari_triangulate(p$P[, 1], p$P[, 2], p$S[, 1], p$S[, 2], ...)
cdtr_run <- function(p, ...) as_tables(cdtr::cdt_pslg(p, ...))

report <- function(nm, p, max_area = NULL, min_angle = NULL) {
  out <- list(laridae = tryCatch(lari(p, max_area = max_area, min_angle = min_angle), error = function(e) e))
  if (has_cdtr) out$cdtr <- tryCatch(cdtr_run(p, max_area = max_area, min_angle = min_angle), error = function(e) e)
  if (has_rtriangle) {
    q <- if (is.null(min_angle)) FALSE else min_angle
    out$RTriangle <- tryCatch(as_tables(if (is.null(max_area)) RTriangle::triangulate(RTriangle::pslg(P = p$P, S = p$S), q = q)
                                        else RTriangle::triangulate(RTriangle::pslg(P = p$P, S = p$S), a = max_area, q = q)),
                              error = function(e) e)
  }
  for (lab in names(out)) {
    r <- out[[lab]]
    if (inherits(r, "error")) { cat(sprintf("  %-9s ERROR %s\n", lab, conditionMessage(r))); next }
    ar <- tri_area(r$vertices, r$triangles); ma <- min_angle(r$vertices, r$triangles)
    cat(sprintf("  %-9s %6d verts %6d tris  area max %.3g  min angle %.2f\n",
                lab, nrow(r$vertices), nrow(r$triangles), max(ar), min(ma)))
  }
  l <- out$laridae
  if (!inherits(l, "error")) {
    cat("  laridae depth table:", paste(names(table(l$triangles$depth)), table(l$triangles$depth), collapse = " "), "\n")
    if (!is.null(l$unrefined)) { cat("  laridae unrefined:\n"); print(l$unrefined) }
  }
  invisible(out)
}

for (nm in names(cases)) {
  p <- cases[[nm]]
  A <- prod(diff(apply(p$P, 2, range)))
  cat("\n==", nm, "constrained only\n"); report(nm, p)
  cat("==", nm, "max_area =", signif(A / 5000, 3), "\n"); report(nm, p, max_area = A / 5000)
  cat("==", nm, "max_area =", signif(A / 5000, 3), "min_angle = 20\n"); report(nm, p, max_area = A / 5000, min_angle = 20)
}

timing <- function(p, iterations, ...) {
  ex <- list(laridae = quote(lari(p, ...)))
  if (has_cdtr) ex$cdtr <- quote(cdtr_run(p, ...))
  if (has_rtriangle) ex$RTriangle <- quote(RTriangle::triangulate(RTriangle::pslg(P = p$P, S = p$S), ...))
  bench::mark(exprs = ex, check = FALSE, iterations = iterations)[, c("expression", "median", "mem_alloc")]
}
cat("\n== timing (nc, max_area = A/5000, min_angle = 20) ==\n")
p <- cases$nc; A <- prod(diff(apply(p$P, 2, range)))
if (has_rtriangle) {
  print(bench::mark(laridae = lari(p, max_area = A / 5000, min_angle = 20),
                    RTriangle = RTriangle::triangulate(RTriangle::pslg(P = p$P, S = p$S), a = A / 5000, q = 20),
                    check = FALSE, iterations = 20)[, c("expression", "median", "mem_alloc")])
}
print(bench::mark(laridae = lari(p, max_area = A / 5000, min_angle = 20),
                  cdtr = if (has_cdtr) cdtr_run(p, max_area = A / 5000, min_angle = 20),
                  check = FALSE, iterations = 20)[, c("expression", "median", "mem_alloc")])
if (!is.null(cases$cad_tas)) {
  cat("\n== timing (cad_tas, constrained only) ==\n")
  p <- cases$cad_tas
  print(bench::mark(laridae = lari(p), cdtr = if (has_cdtr) cdtr_run(p),
                    check = FALSE, iterations = 5)[, c("expression", "median", "mem_alloc")])
}

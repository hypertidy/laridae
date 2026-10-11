## shared by the bench scripts; run from an installed laridae
## needs sf and bench; cdtr and RTriangle are compared when installed, and the
## Tasmanian cases need anglr's data (remotes::install_github("hypertidy/anglr"))
library(laridae); library(sf); library(bench)

## any sf lines or polygons -> deduplicated vertex pool + unique segments,
## the planar straight line graph that silicate::SC0 gives anglr
as_pslg_sf <- function(x) {
  g <- sf::st_geometry(x)
  if (any(sf::st_geometry_type(g) %in% c("POLYGON", "MULTIPOLYGON"))) g <- sf::st_cast(g, "MULTILINESTRING")
  co <- sf::st_coordinates(g)
  lcol <- grep("^L", colnames(co))
  path <- do.call(paste, as.data.frame(co[, lcol, drop = FALSE]))
  xy <- co[, 1:2]
  n <- nrow(xy)
  same <- c(path[-1] == path[-n], FALSE)
  s0 <- which(same); s1 <- s0 + 1L
  key <- paste(xy[, 1], xy[, 2])
  u <- !duplicated(key); map <- match(key, key[u])
  P <- xy[u, , drop = FALSE]; s0 <- map[s0]; s1 <- map[s1]
  seg <- cbind(pmin(s0, s1), pmax(s0, s1))
  seg <- seg[!duplicated(seg) & seg[, 1] != seg[, 2], , drop = FALSE]
  list(P = unname(P), S = unname(seg))
}

tri_area <- function(V, T) {
  0.5 * abs((V$x[T$v1] - V$x[T$v0]) * (V$y[T$v2] - V$y[T$v0]) -
            (V$x[T$v2] - V$x[T$v0]) * (V$y[T$v1] - V$y[T$v0]))
}
min_angle <- function(V, T) {
  l2 <- function(i, j) (V$x[i] - V$x[j])^2 + (V$y[i] - V$y[j])^2
  ab <- l2(T$v0, T$v1); bc <- l2(T$v1, T$v2); ca <- l2(T$v2, T$v0)
  ang <- function(opp, s1, s2) acos(pmin(1, pmax(-1, (s1 + s2 - opp) / (2 * sqrt(s1 * s2)))))
  pmin(ang(bc, ab, ca), ang(ca, ab, bc), ang(ab, bc, ca)) * 180 / pi
}
## cdtr / RTriangle results (P, T matrices) in the laridae table shape
as_tables <- function(r) {
  list(vertices = data.frame(x = r$P[, 1], y = r$P[, 2]),
       triangles = data.frame(v0 = r$T[, 1], v1 = r$T[, 2], v2 = r$T[, 3]))
}

nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
cases <- list(nc = as_pslg_sf(nc))
## anglr is archived on CRAN; its data/ folder (a clone of hypertidy/anglr)
## can stand in via LARIDAE_ANGLR_DATA
anglr_data <- function(name) {
  if (requireNamespace("anglr", quietly = TRUE)) return(getExportedValue("anglr", name))
  dir <- Sys.getenv("LARIDAE_ANGLR_DATA")
  f <- file.path(dir, paste0(name, ".rda"))
  if (!nzchar(dir) || !file.exists(f)) return(NULL)
  e <- new.env(); load(f, envir = e); get(name, e)
}
for (nm in c("cont_tas", "cad_tas")) {
  d <- anglr_data(nm)
  if (!is.null(d)) cases[[nm]] <- as_pslg_sf(d)
}
if (length(cases) == 1L) message("anglr data not found: only the nc case is run")
for (nm in names(cases)) cat(nm, ": ", nrow(cases[[nm]]$P), "vertices", nrow(cases[[nm]]$S), "segments\n")

has_cdtr <- requireNamespace("cdtr", quietly = TRUE)
has_rtriangle <- requireNamespace("RTriangle", quietly = TRUE)

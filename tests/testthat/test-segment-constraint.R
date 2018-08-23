# library(sf)
#
# data("wrld_simpl", package = "maptools")
# x <- st_sfc(purrr::map(st_as_sfc(sp::geometry(wrld_simpl)[c(14, 18)]),
#                        ~st_polygon(.x[[1]][1])))
# sc <- silicate::SC(x)
# ex <- c(91.73665, 93.19351, 21.01719, 22.01933)
# library(dplyr)
# vert <- sc$vertex %>% dplyr::filter(between(x_, ex[1], ex[2]),
#                                     between(y_, ex[3], ex[4]))
# edge <- bind_rows(sc$edge %>% semi_join(vert, c(".vertex0" = "vertex_")),
#                   sc$edge %>% semi_join(vert, c(".vertex1" = "vertex_"))) %>%
#   distinct()
# edge <- edge[edge$.vertex0 %in% vert$vertex_ &
#                edge$.vertex1 %in% vert$vertex_ , ]
#
#
# tri_ve <- function(v, e) {
#   i0 <- match(e$.vertex0, v$vertex_)
#   i1 <- match(e$.vertex1, v$vertex_)
#   RTriangle::triangulate(RTriangle::pslg(P = as.matrix(v[c("x_", "y_")]),
#                                          S = cbind(i0, i1)))
# }
# plot_ve <- function(v, e) {
#   plot(v$x_, v$y_)
#   i0 <- match(e$.vertex0, v$vertex_)
#   i1 <- match(e$.vertex1, v$vertex_)
#   segments(v$x_[i0], v$y_[i0], v$x_[i1], v$y_[i1])
# }
#
# ## there are 6 segments here
# dim(edge)
# ## but apparently only 3
# plot_ve(vert, edge)
# library(spatstat)
# edge_spat <- function(v, e) {
#   i0 <- match(e$.vertex0, v$vertex_)
#   i1 <- match(e$.vertex1, v$vertex_)
#   psp(v$x_[i0], v$y_[i0], v$x_[i1], v$y_[i1],
#                        owin(range(v$x_) + c(-1, 1) * diff(range(v$x_)) * 0.1,
#                             range(v$y_) + c(-1, 1) * diff(range(v$y_)) * 0.1))
# }
# library(silicate)
# sc <- ARC(x)
# sc$arc_link_vertex %>% group_by(arc_) %>% tally()
#
#
# #context("segment-constraint")
# library(laridae)
# library(silicate)
# library(sp)
# library(sf)
# library(dplyr)
# prepare_sf_ct <- function(x, precision = 1e5) {
#   if (abs(precision) > 0) {
#     x <- st_set_geometry(x, st_as_sfc(st_as_binary(st_geometry(x), precision = 100000)))
# }
#   tabs <- silicate::SC(x)
#   segment <-  tibble::tibble(vertex_ = c(t(as.matrix(tabs$edge %>% dplyr::select(.vertex0, .vertex1))))) %>%
#     inner_join(tabs$vertex) %>% mutate(segment_ = (row_number()-1) %/% 2)
#   segs <- split(match(segment$vertex_, tabs$vertex$vertex_) - 1, segment$segment_)
#
#   structure(list(x = tabs$vertex$x_, y = tabs$vertex$y_, segs = segs),
#            class = "psat")
# }
# plot.psat <- function(x, ...) {
#   plot(cbind(x$x, x$y), pch = ".")
#   ind <- index(x)
#   segments(x$x[ind[,1]], x$y[ind[,1]], x$x[ind[,2]], x$y[ind[,2]])
# }
# index <- function(x) {
#   ind <- do.call(rbind, x$segs)
#   t(apply(ind, 1, sort)) + 1
# }
#
#
# dat <- minimal_mesh
# data("wrld_simpl", package = "maptools")
# dat <- st_as_sf( wrld_simpl[c(14, 18), ] )
# psat <- prepare_sf_ct(dat, precision = 0)
# plot(psat)
# anyDuplicated(as.data.frame(index(psat)))
# anyDuplicated(as.data.frame(cbind(psat$x, psat$y)))
# system.time(segment_constraint(psat$x, psat$y, psat$segs))
#
#
#
#
# #context("segment-constraint")
#
# prepare_sf_ct <- function(x) {
#   tabs <- silicate::SC(x)
#   segment <-  tibble::tibble(vertex_ = c(t(as.matrix(tabs$edge %>% dplyr::select(.vertex0, .vertex1))))) %>%
#     inner_join(tabs$vertex) %>% mutate(segment_ = (row_number()-1) %/% 2)
#   segs <- split(match(segment$vertex_, tabs$vertex$vertex_) - 1, segment$segment_)
#
#   list(x = tabs$vertex$x_, y = tabs$vertex$y_, segs = segs)
# }
#
# library(laridae)
# library(silicate)
#
# library(rnaturalearth)
# library(dplyr)
#
# data("wrld_simpl", package = "maptools")
# library(sp)
# #dat <- rnaturalearth::ne_countries(returnclass = "sf")
# library(sf)
# dat <- minimal_mesh
# dat <- st_as_sf(wrld_simpl[, 9])
# #dat <- st_union(dat)
# #dat <- st_sf(geometry = dat, a = 1)
# psat <- prepare_sf_ct(dat)
#
# #library(mapdata)
# #dat <- st_as_sf(map("worldHires", fill = TRUE), plot = FALSE)
# #system.time(psat <- prepare_sf_ct(dat))
#
# #psat <- list(x = c(0, 1), y = c(0, 1), segs = list(c(0, 1)))
# system.time(segment_constraint(psat$x, psat$y, psat$segs))
#
# psfl <- vector("list", nrow(dat))
# for (i in seq_len(nrow(dat))) {
#   psfl[[i]] <- prepare_sf_ct(dat[i, ])
# }
#
# system.time({
#   for (i in seq_len(nrow(dat))) {
#     psf <- psfl[[i]]
#     insert_constraint(psf$x, psf$y, psf$segs)
#   }
# })
#
#
# dwhile (i < nrow(wrld_simpl)) {
#   i <- i + 1
#   print(i)
#
#   dat <- sf::st_as_sf(wrld_simpl[i, ])
#   plot(dat$geometry, asp = "")
#   system.time(psf <- prepare_sf_ct(dat))
#   system.time(insert_constraint(psf$x, psf$y, psf$segs))
#
#   scan("", 1)
# }
#
#
# test_that("prep build and triangulation works", {
#   psf <- prepare_sf_ct(dat)
#   insert_constraint(psf$x, psf$y, psf$segs)
#
# })

## segment pathways

# raster
# triangulations
# per-path segmentation
#
# rgl types seems sensible for quads/triangles
# and as an intermediate form provide the indexing tricks

## we have path-to-segment
## need quad-to-segment
##      tri-to-segment
## and these are rightly done "structurally" since
## the vertices are abstracted out
## but also need
##          segment-to-path
##          and detect if triangle or quad or linestring or standalone

poly_cycles <- function(aa) {
  ii <- 1
  set0 <- ii
  visited <- logical(nrow(aa))
  while(!all(visited)) {
    i0 <- ii
    repeat {
      ii <- which(aa[,1] == aa[ii, 2])
      if (length(ii) < 1 | ii[1] == i0) {
        set0 <- c(set0, NA_integer_)
        break;
      }
      set0 <- c(set0, ii)
    }
    visited <- seq(nrow(aa)) %in% na.omit(set0)
    ii <- which(!visited)[1L]
    if (!is.na(ii)) set0 <- c(set0, ii)
  }
  l <- split(set0, c(0, cumsum(abs(diff(is.na(set0))))))
  bind_rows(lapply(l[!unlist(lapply(l, function(x) all(is.na(x))))], function(x) tibble(row = x)), .id = "cycle")
}

segs <- sc_segment(p)
ind <- segs %>% select(.vertex0, .vertex1) %>%  as.matrix() %>% poly_cycles()
new_paths <- purrr::map_df(split(ind$row, ind$cycle),
                         function(index) tibble(vertex_ = segs[index, c(".vertex0", ".vertex1")] %>%
                                                  as.matrix() %>% t() %>% as.vector()), .id = "path_")
library(ggplot2)
new_paths %>% inner_join(p$vertex) %>%
#  group_by(path_) %>%
  ggplot(aes(x_, y_, col = path_, group = path_)) + geom_path()





#context("segment-constraint")
library(laridae)
library(silicate)
library(sp)
library(sf)
library(dplyr)
prepare_sf_ct <- function(x) {

  tabs <- silicate::SC(x)
  segment <-  tibble::tibble(vertex_ = c(t(as.matrix(tabs$edge %>% dplyr::select(.vertex0, .vertex1))))) %>%
    inner_join(tabs$vertex, "vertex_") %>% mutate(segment_ = (row_number()-1) %/% 2)
  segs <- split(match(segment$vertex_, tabs$vertex$vertex_) - 1, segment$segment_)

  structure(list(x = tabs$vertex$x_, y = tabs$vertex$y_, segs = segs),
            class = "psat")
}


plot.psat <- function(x, ...) {
  plot(cbind(x$x, x$y), pch = ".")
  ind <- index(x)
  segments(x$x[ind[,1]], x$y[ind[,1]], x$x[ind[,2]], x$y[ind[,2]])
}
index <- function(x) {
  ind <- do.call(rbind, x$segs)
  t(apply(ind, 1, sort)) + 1
}
library(spatstat)
as.psp.psat <- function(x, ...) {
  ow <- owin(range(x$x), range(x$y))
  segs <- do.call(rbind, x$segs) + 1
  first <- segs[,1]
  last <- segs[,2]
  psp(x$x[first], x$y[first], x$x[last], x$y[last], window = ow)
}
seg_plot <- function(xy, ind) {
  indx <- matrix(ind, ncol = 3, byrow = TRUE)[, c(1, 2, 3, 1)]
  plot(xy, pch = ".")
  ss <- as.vector(indx[,c(1, 2, 3)])
  ff <- as.vector(indx[,c(2, 3, 1)])
  segments(xy[ss,1], xy[ss, 2], xy[ff, 1], xy[ff, 2])
}

w <- minimal_mesh

f <- raadfiles::thelist_files(pattern = "parcels_hobart")
w <- sf::read_sf(f$fullname)
psat <- prepare_sf_ct(w[1:5000, ])
plot(as.psp(psat))
plot(psat)
ind <- tri_xy(psat$x, psat$y)
seg_plot(cbind(psat$x, psat$y), ind + 1)

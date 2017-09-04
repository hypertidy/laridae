#context("segment-constraint")

prepare_sf_ct <- function(x) {
  tabs <- PRIMITIVE(x)

  segment <-  tibble::tibble(vertex_ = c(t(as.matrix(tabs$segment %>% dplyr::select(.vertex0, .vertex1))))) %>%
    inner_join(tabs$vertex %>% mutate(vertex = row_number() - 1)) %>% mutate(segment = (row_number() + 1) %/% 2)
  segs <- split(segment$vertex, segment$segment)

  list(x = tabs$vertex$x_, y = tabs$vertex$y_, segs = segs)
}

library(seagull)
library(scsf)
library(sc)
library(rnaturalearth)
library(dplyr)

#data("minimal_mesh", package = "scsf")
#dat <- minimal_mesh
data("wrld_simpl", package = "maptools")
library(sp)
dat <- rnaturalearth::ne_countries(returnclass = "sf")
library(sf)
dat <- st_as_sf(wrld_simpl)
dat <- st_union(dat)
dat <- st_sf(geometry = dat, a = 1)
psat <- prepare_sf_ct(dat)

library(mapdata)
dat <- st_as_sf(map("worldHires", fill = TRUE), plot = FALSE)
system.time(psat <- prepare_sf_ct(dat))


system.time(insert_constraint(psat$x, psat$y, psat$segs))

psfl <- vector("list", nrow(dat))
for (i in seq_len(nrow(dat))) {
psfl[[i]] <- prepare_sf_ct(dat[i, ])
}

system.time({
  for (i in seq_len(nrow(dat))) {
  psf <- psfl[[i]]
  insert_constraint(psf$x, psf$y, psf$segs)
}
})


dwhile (i < nrow(wrld_simpl)) {
 i <- i + 1
 print(i)

 dat <- sf::st_as_sf(wrld_simpl[i, ])
 plot(dat$geometry, asp = "")
 system.time(psf <- prepare_sf_ct(dat))
 system.time(insert_constraint(psf$x, psf$y, psf$segs))

 scan("", 1)
}


test_that("prep build and triangulation works", {
  psf <- prepare_sf_ct(dat)
  insert_constraint(psf$x, psf$y, psf$segs)

})

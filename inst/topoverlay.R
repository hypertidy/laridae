
# mpa <- readOGR("inst", "MPA_combined")
# projection(mpa) <- "+proj=laea +lon_0=100 +lat_0=-90 +ellps=WGS84"
#
# library(raadtools)
# r <- readtopo("ibcso", polar = TRUE)
# projection(r) <- "+proj=stere +lat_ts=-71 +lat_0=-90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +units=m +no_defs"
# topo <- crop(r, projectExtent(raster(mpa), projection(r)), file = sprintf("%s.grd", tempfile()))
# topo1 <- aggregate(topo, fact = 32, file = sprintf("%s.grd", tempfile()))
# mpa <- spTransform(mpa, CRS(projection(topo)))
#
# levs <- c(-1, -500, -1000, -2000, -4000)
# p1 <- data_frame()
# for (i in seq_along(levs[-1])) {
#   cl <- rgeos::gUnionCascaded(rgeos::gPolygonize(rasterToContour(topo1, lev = levs[i + 1])))
#
#   c0 <- bld(SpatialPolygonsDataFrame(cl, data.frame(depth = levs[i + 1])))$v
#   if (i > 1) c0 <- c0 %>% mutate(.br0 = .br0 + max(p1$.br0), .ob0 = .ob0 + max(p1$.br0))
#   p1 <- bind_rows(p1, c0)
# }
#
# p2 <- bld(mpa)
# cl <- rasterToContour(topo1 < -1 & topo1 > -250, lev = 0)
#

densify <- function(x, n = 2) {
  m <- as.matrix(x %>% select(x, y))[c(seq(nrow(x)), 1), ]
  ##m <- cbind(x, y)[c(seq(length(x)), 1), ]
  nn <- seq(nrow(m))
  nout <- sort(unique(c(nn, seq(min(nn), max(nn), length = length(nn) * n))))
  m <- tail(cbind(approx(nn, m[,1], xout = nout)$y, approx(nn, m[,2], xout = nout)$y), -1)
  data_frame(x = m[,1], y = m[,2])
}

library(maptools)
data(wrld_simpl)
library(raster)
library(gris)
library(cgalgris)
library(rgdal)
library(rworldxtra)
data(countriesHigh)
ngrid <- c(100, 140) / 4
w <- disaggregate(subset(countriesHigh, NAME == "Australia"))[c(2, 7, 9),]
pp <- as(setValues(raster(w, ncol = ngrid[1], nrow = ngrid[2]), seq(prod(ngrid))), "SpatialPolygonsDataFrame")
p1 <- bld(pp)
p2 <- bld(w)


p2$tri <- tri_xy(p2$v$x, p2$v$y) + 1
p2tri <- p2$v[p2$tri, ]
p2tri$tid <- rep(seq(nrow(p2tri)/3), each = 3)

l <- vector("list", max(p2tri$tid))
for (i in seq(max(p2tri$tid))) l[[i]] <- densify(p2tri %>% filter(tid == i), n = 2) %>% mutate(.br0 = i)
p2dens <- do.call(bind_rows, l)

p2$v <- p2dens %>% mutate(.ob0 = 1, id = seq(nrow(p2dens)))

##

## all triangles
tri <- tri_xy(c(p1$v$x, p2$v$x), c(p1$v$y, p2$v$y)) + 1
## p1 vertices split into branches
#x1 <- p1$v %>% mutate(mg = .br0) %>%  group_by(mg) %>% do(rbind(., NA_real_))
#x2 <- bld(w)$v %>% mutate(mg = .br0) %>%  group_by(mg) %>% do(rbind(., NA_real_))
x1 <- p1$v
x2 <- bld(w)$v
## centroids of triangles
centr <- data_frame(x = c(p1$v$x, p2$v$x)[tri], y = c(p1$v$y, p2$v$y)[tri], t = rep(seq(length(tri)/3), each = 3)) %>%
  group_by(t) %>% summarize(x = mean(x), y = mean(y)) %>% select(x, y, t)
p1_tri <- point.in.polygon(centr$x, centr$y, x1$x, x1$y) > 0
p2_tri <- point.in.polygon(centr$x, centr$y, x2$x, x2$y) > 0

fun <- function(xx, yy) point.in.polygon(centr$x, centr$y, xx, yy) > 0
gx1 <- x1 %>% group_by(.br0) ##%>% mutate(pip = fun(x, y))

centr$p1 <- !is.na(over(SpatialPoints(as.matrix(centr[, c("x", "y")]), CRS(proj4string(pp))), as(pp, "SpatialPolygons")))
centr$p2 <- !is.na(over(SpatialPoints(as.matrix(centr[, c("x", "y")]), CRS(proj4string(w))), as(w, "SpatialPolygons")))
#p1_tri <- unlist(lapply(split(x1, x1$.br0), function(x) point.in.polygon(centr$x, centr$y, x$x, x$y) > 0))
#p2_tri <- unlist(lapply(split(x2, x2$.br0), function(x) point.in.polygon(centr$x, centr$y, x$x, x$y) > 0))

## table of combined triangle centres
#centr$p1 <- p1_tri
#centr$p2 <- p2_tri
##tmp <_ matrix(tri, ncol = 3, byrow = TRUE)
centr$t0 <- tri[seq(1, length(tri), by = 3)]
centr$t1 <- tri[seq(2, length(tri), by = 3)]
centr$t2 <- tri[seq(3, length(tri), by = 3)]


pl(p2$v)
points(p2$v[, c("x", "y")], pch = 16, cex = 0.4)

apply(as.matrix(centr %>% filter(p2) %>% select(t0, t1, t2)), 1,
      function(x) polypath(cbind(c(p1$v$x, p2$v$x)[x], c(p1$v$y, p2$v$y)[x]), col = "#0066FF99", border = rgb(0, 0, 0, 0.2)))






plot(w, xlim = c(147.8, 148.2), ylim = c(-43.5, -42.5), asp = "")
apply(as.matrix(centr %>% filter(p2 & x > 147.8 & y < -42.5) %>% select(t0, t1, t2)), 1,
      function(x) polypath(cbind(c(p1$v$x, p2$v$x)[x], c(p1$v$y, p2$v$y)[x]), col = "#0066FF99", border = rgb(0, 0, 0, 0.2)))





# e <- new("Extent"
#          , xmin = 147.820314165763
#          , xmax = 147.954301618001
#          , ymin = -42.6395314243213
#          , ymax = -42.4571216065452
# )
#
# par(mfrow = c(2, 1), mar = rep(0.05, 4))
# plot(e); plot(w, add = TRUE)
# apply(as.matrix(centr %>% filter(p2) %>% select(t0, t1, t2)), 1,
#       function(x) polypath(cbind(c(p1$v$x, p2$v$x)[x], c(p1$v$y, p2$v$y)[x]), col = "#0066FF99", border = rgb(0, 0, 0, 0.2)))
#
# plot(e);
# apply(as.matrix(centr  %>% select(t0, t1, t2)), 1,
#       function(x) polypath(cbind(c(p1$v$x, p2$v$x)[x], c(p1$v$y, p2$v$y)[x]), col = "#0066FF99", border = rgb(0, 0, 0, 0.2)))
# plot(w, add = TRUE, border = "firebrick", lty = 2, lwd = 4)
#

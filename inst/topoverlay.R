library(maptools)
data(wrld_simpl)
library(raster)
library(gris)
library(cgalgris)

library(rworldxtra)
data(countriesHigh)
w <- disaggregate(subset(countriesHigh, NAME == "Australia"))[c(2, 7, 9),]
ngrid <- c(100, 140) / 2
p1 <- bld(as(setValues(raster(w, ncol = ngrid[1], nrow = ngrid[2]), seq(prod(ngrid))), "SpatialPolygonsDataFrame"))
p2 <- bld(w)

#pl(p1$v, col = sample(grey(seq(0.3, 0.7, length = max(p1$v$.ob0)))))
#plot(w,add = TRUE, border = "#0066FFFF", lwd = 2)

p2$tri <- tri_xy(p2$v$x, p2$v$y) + 1
p2tri <- p2$v[p2$tri, ]
p2tri$tid <- rep(seq(nrow(p2tri)/3), each = 3)
densify <- function(x, n = 2) {
  m <- as.matrix(x %>% select(x, y))[c(seq(nrow(x)), 1), ]
  ##m <- cbind(x, y)[c(seq(length(x)), 1), ]
  nn <- seq(nrow(m))
  nout <- sort(unique(c(nn, seq(min(nn), max(nn), length = length(nn) * n))))
  m <- tail(cbind(approx(nn, m[,1], xout = nout)$y, approx(nn, m[,2], xout = nout)$y), -1)
  data_frame(x = m[,1], y = m[,2])
}


l <- vector("list", max(p2tri$tid))
for (i in seq(max(p2tri$tid))) l[[i]] <- densify(p2tri %>% filter(tid == i), n = 5) %>% mutate(.br0 = i)
p2dens <- do.call(bind_rows, l)

p2$v <- p2dens %>% mutate(.ob0 = 1, id = seq(nrow(p2dens)))

##pl(p2$v)

## all triangles
tri <- tri_xy(c(p1$v$x, p2$v$x), c(p1$v$y, p2$v$y)) + 1
## p1 vertices split into branches
x1 <- p1$v %>% mutate(mg = .br0) %>%  group_by(mg) %>% do(rbind(., NA_real_))
x2 <- bld(w)$v %>% mutate(mg = .br0) %>%  group_by(mg) %>% do(rbind(., NA_real_))
## centroids of triangles
centr <- data_frame(x = c(p1$v$x, p2$v$x)[tri], y = c(p1$v$y, p2$v$y)[tri], t = rep(seq(length(tri)/3), each = 3)) %>%
  group_by(t) %>% summarize(x = mean(x), y = mean(y)) %>% select(x, y, t)
p1_tri <- point.in.polygon(centr$x, centr$y, x1$x, x1$y) == 1
p2_tri <- point.in.polygon(centr$x, centr$y, x2$x, x2$y) == 1

centr$p1 <- p1_tri
centr$p2 <- p2_tri

plot(w, asp = NA)
apply(matrix(tri, ncol = 3, byrow = TRUE)[centr$p2, ], 1,
      function(x) polypath(cbind(c(p1$v$x, p2$v$x)[x], c(p1$v$y, p2$v$y)[x]), col = "#0066FF99", border = rgb(0, 0, 0, 0.2)))




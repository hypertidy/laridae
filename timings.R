#x    <- c(2.3,3.0,7.0,1.0,3.0,8.0)
#y    <- c(2.3,3.0,2.0,5.0,8.0,9.0)

set.seed(90)
x <- rnorm(80, sd = 4)
y <- rnorm(80, sd = 2)
library(cgalgris)
#' plot a matrix xy as points
#' and add the triangulation indexed
#' by structural triplet row-identifiers
poly_index <- function(xy, index, ...) {
  plot(xy, ...)
  ## assume index is 0,1,2,0,1,2,0,1,...
  ii <- c(rbind(matrix(index, nrow = 3), NA_integer_))
  ## have forgetten why polypath fails, so just use polygon
  polygon(xy[ii, 1], xy[ii, 2])
}


library(dplyr)
library(tibble)
#xy <- cbind(x, y)  %>% as_tibble() %>% arrange(x, desc(y)) %>% as.matrix()
xy <- cbind(x, y)
system.time({
  ind_t <- tri_xy(xy[,1], xy[,2]) + 1
})
length(ind_t)

ps <- RTriangle::pslg(P = xy)
system.time({
  ind_T <- c(t(RTriangle::triangulate(ps)$T))
})
length(ind_T)

par(mfrow = c(2, 1), mar = rep(0, 4))
poly_index(xy, ind_t, pch = ".")
poly_index(xy, ind_T, pch = ".")


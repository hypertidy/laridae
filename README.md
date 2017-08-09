
[![Travis-CI Build Status](https://travis-ci.org/r-gris/cgalgris.svg?branch=master)](https://travis-ci.org/r-gris/cgalgris) [![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/r-gris/cgalgris?branch=master&svg=true)](https://ci.appveyor.com/project/r-gris/cgalgris) [![Coverage Status](https://img.shields.io/codecov/c/github/r-gris/cgalgris/master.svg)](https://codecov.io/github/r-gris/cgalgris?branch=master)

<!-- README.md is generated from README.Rmd. Please edit that file -->
`cgalgris` came out of a need for constrained triangulation for a topology-in-R project. That effort has moved on somewhat, proving the case by using `RTriangle` and then bedding down the normalization model in the `mdsumner/sc` package.

Today (August 2017) this is just to explore the CGAL API from R, particularly for feeding it vertex pools and constraints from `sc`-like decompositions. It's not clear how path/edge models are best translated, but maybe we can figure that out here.

The interest in constrained triangulations is discussed here along with the overall landscape in R.

<https://github.com/r-spatial/discuss/issues/6>

### Triangulation

Triangulate with CGAL via [cgalgris](https://github.com/mdsumner/cgalgris). The function `tri_xy` performs an exact Delaunay triangulation on all vertices, returning a triplet-index for each triangle (zero-based in CGAL).

Some timings, to show we aren't wildly off-base and that CGAL wins for raw unconstrained Delaunay triangulation.

``` r
#x    <- c(2.3,3.0,7.0,1.0,3.0,8.0)
#y    <- c(2.3,3.0,2.0,5.0,8.0,9.0)

set.seed(90)
x <- rnorm(1e3, sd = 4)
y <- rnorm(1e3, sd = 2)
#x <- c(0, 0, 1, 1)
#y <- c(0, 1, 1, 0)
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
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(tibble)
#xy <- cbind(x, y)  %>% as_tibble() %>% arrange(x, desc(y)) %>% as.matrix()
xy <- cbind(x, y)
system.time({
  ind_t <- tri_xy(xy[,1], xy[,2]) + 1
})
#>    user  system elapsed 
#>   0.002   0.000   0.003
system.time({
  ind_t1 <- tri_xy1(xy[,1], xy[,2]) + 1
})
#>    user  system elapsed 
#>   0.001   0.000   0.001
system.time({
  ind_t2 <- tri_xy2(xy[,1], xy[,2]) + 1
})
#>    user  system elapsed 
#>   0.001   0.000   0.001

length(ind_t)
#> [1] 5961
length(ind_t1)
#> [1] 5961
length(ind_t2)
#> [1] 5961


ps <- RTriangle::pslg(P = xy)
system.time({
  ind_T <- c(t(RTriangle::triangulate(ps)$T))
})
#>    user  system elapsed 
#>   0.002   0.000   0.003
length(ind_T)
#> [1] 5961

par(mfrow = c(2, 2), mar = rep(0, 4))
poly_index(xy, ind_t, pch = ".")
## can't work as order is not aligned, but still fun
poly_index(xy, ind_t1, pch = ".")  
poly_index(xy, ind_t2, pch = ".")

poly_index(xy, ind_T, pch = ".")
```

![](README-unnamed-chunk-2-1.png)

Setup
-----

``` r
tools::package_native_routine_registration_skeleton("../cgalgris", "src/init.c",character_only = FALSE)
```

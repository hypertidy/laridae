
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
#>   0.001   0.000   0.002
system.time({
  ind_t1 <- tri_xy1(xy[,1], xy[,2]) + 1
})
#>    user  system elapsed 
#>   0.001   0.000   0.002
system.time({
  ind_t2 <- tri_xy2(xy[,1], xy[,2]) + 1
})
#>    user  system elapsed 
#>   0.001   0.000   0.002

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
#>   0.002   0.000   0.002
length(ind_T)
#> [1] 5961

p <- par(mfrow = c(2, 2), mar = rep(0, 4))
poly_index(xy, ind_t, pch = ".")
## can't work as order is not aligned, but still fun
poly_index(xy, ind_t1, pch = ".")  
poly_index(xy, ind_t2, pch = ".")
poly_index(xy, ind_T, pch = ".")
```

![](README-unnamed-chunk-2-1.png)

``` r
par(p)


## other comparisons
library(deldir)
#> deldir 0.1-14
system.time(dl <- deldir::deldir(x, y))
#> 
#>      PLEASE NOTE:  The components "delsgs" and "summary" of the
#>  object returned by deldir() are now DATA FRAMES rather than
#>  matrices (as they were prior to release 0.0-18).
#>  See help("deldir").
#>  
#>      PLEASE NOTE: The process that deldir() uses for determining
#>  duplicated points has changed from that used in version
#>  0.0-9 of this package (and previously). See help("deldir").
#>    user  system elapsed 
#>   0.053   0.004   0.058
plot(dl)
```

![](README-unnamed-chunk-2-2.png)

``` r
library(geometry)
#> Loading required package: magic
#> Loading required package: abind
system.time(gm <- geometry::delaunayn(xy))
#> 
#>      PLEASE NOTE:  As of version 0.3-5, no degenerate (zero area) 
#>      regions are returned with the "Qt" option since the R 
#>      code removes them from the triangulation. 
#>      See help("delaunayn").
#>    user  system elapsed 
#>   0.007   0.004   0.011
poly_index(xy, c(t(gm)))

## sf comparison
library(dplyr)
library(sf)
#> Linking to GEOS 3.5.1, GDAL 2.2.1, proj.4 4.9.3
```

![](README-unnamed-chunk-2-3.png)

``` r
d <- st_as_sf(tibble::as_tibble(xy) %>% mutate(a = row_number()), coords = c("x", "y"))
## timing is unfair as sf must be decomposed and recomposed
## and every triangle has four coordinates, no sharing allowed
## and probably sfdct is slow ..
library(sfdct)
## this doesn't do anything, same as rgl::triangulate must
## have edge inputs
##system.time(sfd <- st_triangulate(d))
system.time(dt <- ct_triangulate(d))
#> all POINT, returning one feature triangulated
#>    user  system elapsed 
#>   0.391   0.043   0.435
plot(dt, col = "transparent", border = "black")
```

![](README-unnamed-chunk-2-4.png)

Setup
-----

``` r
tools::package_native_routine_registration_skeleton("../cgalgris", "src/init.c",character_only = FALSE)
```

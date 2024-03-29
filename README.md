
<!-- badges: start -->

[![R-CMD-check](https://github.com/hypertidy/laridae/workflows/R-CMD-check/badge.svg)](https://github.com/hypertidy/laridae/actions)
<!-- badges: end -->

<!-- README.md is generated from README.Rmd. Please edit that file -->

Work in progress to get constrained and conforming Delaunay
triangulation for shapes in R with CGAL. We have

-   point-only triangulation in `tri_xy()` - it’s fast
-   segment-input constraints in `insert_mesh()` - only returns the
    vertices, which might include new points
-   constrained and conformal triangulations in-progress …

We need:

-   export of new vertex pool and its edge- or triangle-based indices
-   proper inputs of nested polygon shapes
-   robust dealing with segment and polygon soups, so that numeric
    insertions are robust (and c.)

We can now hit this more easily thanks to
[cgal4h](https://CRAN.R-project.org/package=cgal4h) thanks to Ahmadou
Dicko.

`laridae` came out of a need for constrained triangulation for a
topology-in-R project. That effort has moved on somewhat, proving the
case by using `RTriangle` and then bedding down the normalization model
in the `hypertidy/silicate` package.

R now has [cgal4h](https://cran.r-project.org/package=cgal4h) providing
the library infrastructure for CGAL and
[euclid](https:://github.com/thomasp85/euclid) providing numerically
robust geometric primitives (it’s unclear if laridae or whatever it
becomes will use euclid).

RTriangle is really fast, but it’s not as fast as CGAL. CGAL can also be
used to update a triangulation, which means (I think) that we could
build an unconstrained triangulation from all the coordinates, and then
add in any segments, even unclosed linear paths. At any rate, being able
to update a mesh has a lot of applications, especially for neighbouring
shapes, and for on-demand (extent or zoom dependent level of detail)
tasks.

The interest (which seems miniscule …) in constrained triangulations is
discussed here along with the overall landscape in R.

<https://github.com/r-spatial/discuss/issues/6>

## Installation

``` r
remotes::install_github("hypertidy/laridae")
## not universe ready yet
#install.packages("laridae", repos = "https://hypertidy.r-universe.dev")
```

## Triangulation

Triangulate with CGAL via
[laridae](https://github.com/hypertidy/laridae). The function `tri_xy`
performs an exact Delaunay triangulation on all vertices, returning a
triplet-index for each triangle (zero-based in CGAL).

The variants `tri_xy1()` and `tri_xy2()` work slightly differently
illustrating CGAL usage in C++ (thanks to Mark Padgham). ‘xy1’ order is
not trivial … but we ignore that for now.

``` r
library(laridae)
x <- c(0, 0, 1)
y <- c(0, 1, 1)
plot(x, y, pch = "+")
(idx0 <- tri_xy(x, y))
#> [1] 3 2 1
(idx1 <- tri_xy1(x, y))
#> [1] 2 3 1
(idx2 <- tri_xy2(x, y))
#> [1] 3 2 1

polygon(cbind(x, y)[idx0, ])
```

<img src="man/figures/README-triangle-1.png" width="100%" />

``` r
x    <- c(2.3,3.0,7.0,1.0,3.0,8.0)
y    <- c(2.3,3.0,2.0,5.0,8.0,9.0)
idx <- tri_xy(x, y)
plot(x, y, pch = "+", cex = 1.5)
polygon(cbind(x, y)[rbind(matrix(idx, 3L), NA), ], lty = 3)
```

<img src="man/figures/README-triangle-2.png" width="100%" />

Some timings, to show we aren’t wildly off-base and that CGAL wins for
raw unconstrained Delaunay triangulation.

``` r
set.seed(90)
x <- rnorm(1e3, sd = 4)
y <- rnorm(1e3, sd = 2)
library(laridae)

# plot a matrix xy as points
# and add the triangulation indexed
# by structural triplet row-identifiers
poly_index <- function(xy, index, ...) {
  plot(xy, ...)
  ## assume index is 0,1,2,0,1,2,0,1,...
  ii <- c(rbind(matrix(index, nrow = 3), NA_integer_))
  ## have forgetten why polypath fails, so just use polygon
  polygon(xy[ii, 1], xy[ii, 2])
}


ps <- RTriangle::pslg(P = cbind(x, y))

microbenchmark::microbenchmark(
  ind_t <- tri_xy(x, y), 
  ind_t1 <- tri_xy1(x, y), 
  ind_t2 <- tri_xy2(x, y), 
  RT <- RTriangle::triangulate(ps)
)
#> Unit: microseconds
#>                              expr      min       lq     mean   median       uq
#>             ind_t <- tri_xy(x, y)  958.795 1127.766 1184.248 1202.551 1244.693
#>           ind_t1 <- tri_xy1(x, y)  964.334 1111.205 1180.227 1187.096 1239.847
#>           ind_t2 <- tri_xy2(x, y)  968.167 1116.894 1177.740 1199.422 1242.877
#>  RT <- RTriangle::triangulate(ps) 1677.312 1972.573 2076.233 2078.806 2194.787
#>       max neval cld
#>  1412.635   100  a 
#>  1489.043   100  a 
#>  1408.256   100  a 
#>  2371.038   100   b
length(ind_t)
#> [1] 5961
length(ind_t1)
#> [1] 5961
length(ind_t2)
#> [1] 5961
length(RT$T)
#> [1] 5961


p <- par(mfrow = c(2, 2), mar = rep(0, 4))
poly_index(cbind(x, y), ind_t, pch = ".")
## can't work as order is not aligned, but still fun
poly_index(cbind(x, y), ind_t1, pch = ".")  
poly_index(cbind(x, y), ind_t2, pch = ".")
plot(RT)
```

<img src="man/figures/README-unnamed-chunk-2-1.png" width="100%" />

``` r
par(p)
```

## Constrained triangulation

Currently laridae only has vertex-output and “reporting” of the result.
I can’t yet see how to

-   get the vertex pool (it may have expanded given mesh properties,
    overlapping segments, etc.)
-   get the triangle index

The only other implementation in R is in RTriangle, so we use that for
comparison.

``` r
sfx <- silicate::inlandwaters
sc <- silicate::SC(sfx)
X <- sc$vertex$x_
Y <- sc$vertex$y_
i0 <- match(sc$edge$.vx0, sc$vertex$vertex_)
i1 <- match(sc$edge$.vx1, sc$vertex$vertex_)

system.time(insert_constraint(X, Y, i0 , i1))
#> Number of vertices before: 30835
#> Number of vertices after: 31079
#>    user  system elapsed 
#>   0.368   0.000   0.367
system.time(segment_constraint(sc))
#> The number of resulting constrained edges is: 30843
#>    user  system elapsed 
#>   0.392   0.000   0.393

## insert_mesh actually returns the vertices (which might include new ones)
system.time(xy_out <- insert_mesh(X, Y, i0 , i1))
#> Number of vertices before: 30835
#> Number of vertices after: 31079
#>    user  system elapsed 
#>   0.075   0.000   0.075
plot(xy_out, pch = ".")
```

<img src="man/figures/README-mesh-input-1.png" width="100%" />

``` r
## compare RTriangle, it's fast if we don't include pslg() time
ps <- RTriangle::pslg(cbind(X, Y), S = cbind(i0, i1))
system.time({
  tr <- RTriangle::triangulate(ps, D = TRUE)
})
#>    user  system elapsed 
#>   0.079   0.000   0.079


plot(tr$P, pch= ".")
segments(tr$P[tr$E[,1],1], tr$P[tr$E[,1],2], 
         tr$P[tr$E[,2],1], tr$P[tr$E[,2],2])
```

<img src="man/figures/README-mesh-input-2.png" width="100%" />

``` r
str(tr)
#> List of 12
#>  $ P : num [1:31778, 1:2] -681074 -680885 -680821 -680474 -680376 ...
#>  $ PB: int [1:31778, 1] 1 1 1 1 1 1 1 1 1 1 ...
#>  $ PA: num[1:31778, 0 ] 
#>  $ T : int [1:43051, 1:3] 4455 4455 4510 4542 4510 4410 4376 4380 4397 4390 ...
#>  $ S : int [1:31786, 1:2] 24305 24316 24328 24328 24326 24321 24343 24354 24349 24349 ...
#>  $ SB: int [1:31786, 1] 0 0 0 0 0 0 0 0 0 0 ...
#>  $ E : int [1:74679, 1:2] 4455 4456 4492 4492 4542 4510 4492 4542 4562 4492 ...
#>  $ EB: int [1:74679, 1] 1 1 0 0 0 1 0 1 0 1 ...
#>  $ VP: num [1:43051, 1:2] 51155 52903 52733 54473 52163 ...
#>  $ VE: int [1:74679, 1:2] 1 1 1 2 2 3 3 4 4 5 ...
#>  $ VN: num [1:43051, 1:2] -2148 -124 0 0 0 ...
#>  $ VA: num[1:43051, 0 ] 
#>  - attr(*, "class")= chr "triangulation"
```

## History

Was originally called `cgalgris`.

## Code of Conduct

Please note that the laridae project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/1/0/0/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

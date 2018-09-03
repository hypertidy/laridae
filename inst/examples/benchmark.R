n <- 100000
xy <- cbind(runif(n), runif(n))
## grid for akima
grid <- expand.grid(x = seq(0, 1, length = as.integer(sqrt(n))), y = seq(0, 1, length = as.integer(sqrt(n))))

## these choice were
## 1) easy for me to try out
## 2) are pure Delaunay convex hull triangulation on bare points (akima is different, uses triangulation under the hood)
rbenchmark::benchmark(
  ## akima doesn't really belong
  #akima = akima::interpp(xy[,1], xy[,2], z = rep(0, n), xo = grid$x, yo = grid$y),
 # deldir = deldir::deldir(xy[,1], xy[,2], suppressMsge = TRUE),
  CGAL = laridae::tri_xy(xy[,1], xy[,2]),
  geometry = geometry::delaunayn(xy, options = "Pp"),
 # rgeos = rgeos::gDelaunayTriangulation(sp::SpatialPoints(xy)),
  RTriangle = RTriangle::triangulate(RTriangle::pslg(xy)),
 # sf = sf::st_triangulate(sf::st_sfc(sf::st_multipoint(xy))),
  ## spatstat belongs but is the slowest
  #spatstat = spatstat::delaunay(spatstat::ppp(xy[,1], xy[,2], window = spatstat::owin(range(xy[,1]), range(xy[,2])))),
  tripack = tripack::tri.mesh(xy[,1], xy[,2]),
  replications = 10,
  order = "relative",
  columns = c('test', 'elapsed', 'relative', 'user.self', 'sys.self')
)

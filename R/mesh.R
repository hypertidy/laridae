insert_mesh <- function(X, Y, n, l) {
   .C("insert_mesh",
   n = as.integer(ncol(l)),
   x_ = as.double(X), y_ = as.double(Y),
   i0 = as.integer(l[1, ]), i1 = as.integer(l[2, ]),
   NAOK=TRUE, PACKAGE = "laridae")
}

#include <Rcpp.h>
using namespace Rcpp;

#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_conformer_2.h>
#include <iostream>
typedef CGAL::Exact_predicates_inexact_constructions_kernel K;
typedef CGAL::Exact_predicates_tag Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, CGAL::Default, Itag> CDT;
typedef CDT::Point Point;
typedef CDT::Vertex_handle Vertex_handle;

// [[Rcpp::export]]
IntegerVector insert_mesh(NumericVector X,
                          NumericVector Y,
                          IntegerVector I0,
                          IntegerVector I1)
{
  CDT cdt;

  int np = X.length();
  int n = I0.length();
  double *x_ = new double[np];
  double *y_ = new double[np];
  int *i0 = new int[n];
  int *i1 = new int[n];
  for (int i = 0; i < np; i++) {
   x_[i] = X[i];
   y_[i] = Y[i];
  }
  for (int i = 0; i < n; i++) {
    i0[i] = I0[i];
    i1[i] = I1[i];
  }

  Vertex_handle vh0, vh1;
  std::vector<Point> points;
  std::vector<std::pair<int, int>> ii;
   for (int i = 0; i < np; i++) {
      points.push_back(Point(x_[i], y_[i]));
  }
  //  https://doc.cgal.org/4.14.2/Triangulation_2/classCGAL_1_1Constrained__Delaunay__triangulation__2.html#a3707074708b073b8526d5d7d0f03fbb4
  for (int i = 0; i < n; i++) {
    ii.push_back(std::pair<int, int>(i0[i], i1[i]));
  }
  delete x_;
  delete y_;
  delete i0;
  delete i1;

  // insert segment constraints in one go (takes about 10 times longer otherwise for 30000 points)
  cdt.insert_constraints(points.begin(), points.end(),
                         ii.begin(), ii.end());

  Rprintf("Number of vertices before: %i\n", cdt.number_of_vertices());
  // make it conforming Delaunay
  CGAL::make_conforming_Delaunay_2(cdt);
  Rprintf("Number of vertices after: %i\n", cdt.number_of_vertices());
  return Rcpp::IntegerVector::create(NA_INTEGER);
}

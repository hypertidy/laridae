#include <Rcpp.h>
using namespace Rcpp;

#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_conformer_2.h>
#include <iostream>
typedef CGAL::Exact_predicates_inexact_constructions_kernel K;
typedef CGAL::Exact_predicates_tag                               Itag;
//Need Itag to get intersecting segments
typedef CGAL::Constrained_Delaunay_triangulation_2<K, CGAL::Default, Itag> CDT;
typedef CDT::Point Point;
typedef CDT::Vertex_handle Vertex_handle;

// [[Rcpp::export]]
IntegerVector insert_constraint_cpp(NumericVector x, NumericVector y,
                                IntegerVector v0, IntegerVector v1)
{
  CDT cdt;
//  int n = segment.size();
  int n = v0.length();
  Vertex_handle vh0, vh1;

  for (int i = 0; i < n; i++) {
    vh0 = cdt.insert(Point(x[v0[i]], y[v0[i]]));
    vh1 = cdt.insert(Point(x[v1[i]], y[v1[i]]));
    cdt.insert_constraint(vh0,vh1);
  }

  // http://doc.cgal.org/latest/Mesh_2/index.html
  Rprintf("Number of vertices before: %i\n", cdt.number_of_vertices());
  // make it conforming Delaunay
  CGAL::make_conforming_Delaunay_2(cdt);
  Rprintf("Number of vertices after: %i\n", cdt.number_of_vertices());
  return 0;
}

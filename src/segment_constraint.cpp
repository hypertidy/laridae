#include <Rcpp.h>
using namespace Rcpp;

#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <cassert>
#include <iostream>
typedef CGAL::Exact_predicates_inexact_constructions_kernel K;
typedef CGAL::Exact_predicates_tag                               Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, CGAL::Default, Itag> CDT;
typedef CDT::Point          Point;


// FROM example 8.3: https://doc.cgal.org/4.11.3/Triangulation_2/index.html
// [[Rcpp::export]]
IntegerVector segment_constraint_cpp(NumericVector x, NumericVector y, List segment)
{
  CDT cdt;
  int first, second;
  IntegerVector ind;
  for (int i = 0; i < segment.length(); ++i) {
    ind = segment[i];
    first = ind[0];
    second = ind[1];
    cdt.insert_constraint( Point(x[first], y[first]),
                           Point(x[second], y[second]));
  }
  assert(cdt.is_valid());
  int count = 0;
  for (CDT::Finite_edges_iterator eit = cdt.finite_edges_begin();
       eit != cdt.finite_edges_end();
       ++eit) {
    if (cdt.is_constrained(*eit)) ++count;
  }

  Rprintf("The number of resulting constrained edges is: %i\n", count);
  IntegerVector xout = IntegerVector::create(NA_INTEGER);
  return xout;
}

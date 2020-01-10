#include <Rcpp.h>
using namespace Rcpp;

#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_conformer_2.h>
#include <iostream>
typedef CGAL::Exact_predicates_inexact_constructions_kernel K;
typedef CGAL::Constrained_Delaunay_triangulation_2<K> CDT;
typedef CDT::Point Point;
typedef CDT::Vertex_handle Vertex_handle;

//' Insert segment constraint
//'
//' @param x x coordinate
//' @param y y coordinate
//' @param segment list of segment pairs (index into x,y)
// [[Rcpp::export]]
IntegerVector segment_constraint(NumericVector x, NumericVector y, List segment)
{
  CDT cdt;
  int n = segment.size();
  Vertex_handle vh0, vh1;
  int first, second;
  for (int i = 0; i < n; i++) {
    IntegerVector ind = segment[i];
    first = ind[0];
    second = ind[1];
//printf("%i\n", i);
    vh0 = cdt.insert(Point(x[first], y[first]));
    vh1 = cdt.insert(Point(x[second], y[second]));
    cdt.insert_constraint(vh0,vh1);
  }

  // http://doc.cgal.org/latest/Mesh_2/index.html
std::cout << "Number of vertices before: "
            << cdt.number_of_vertices() << std::endl;
  // make it conforming Delaunay
  CGAL::make_conforming_Delaunay_2(cdt);
  std::cout << "Number of vertices after make_conforming_Delaunay_2: "
            << cdt.number_of_vertices() << std::endl;
  // then make it conforming Gabriel
  CGAL::make_conforming_Gabriel_2(cdt);
  std::cout << "Number of vertices after make_conforming_Gabriel_2: "
            << cdt.number_of_vertices() << std::endl;
  return 0;
}

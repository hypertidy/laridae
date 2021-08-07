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
List insert_mesh_cpp(NumericVector x,
                          NumericVector y,
                          IntegerVector v0,
                          IntegerVector v1)
{
  CDT cdt;

  int np = x.length();
  int n = v0.length();

  std::vector<Point> points;
  std::vector<std::pair<int, int>> ii;
   for (int ip = 0; ip < np; ip++) {
      points.push_back(Point(x[ip], y[ip]));
  }
  //  https://doc.cgal.org/4.14.2/Triangulation_2/classCGAL_1_1Constrained__Delaunay__triangulation__2.html#a3707074708b073b8526d5d7d0f03fbb4
  for (int il = 0; il < n; il++) {
    ii.push_back(std::pair<int, int>(v0[il], v1[il]));
  }

  // insert segment constraints in one go (takes about 10 times longer otherwise for 30000 points)
  cdt.insert_constraints(points.begin(), points.end(),
                         ii.begin(), ii.end());

  Rprintf("Number of vertices before: %i\n", cdt.number_of_vertices());
  // make it conforming Delaunay
  CGAL::make_conforming_Delaunay_2(cdt);

  NumericVector xi = NumericVector(cdt.number_of_vertices());
  NumericVector yi = NumericVector(cdt.number_of_vertices());

  int i = 0;
  for (auto itr = cdt.finite_vertices_begin(); itr != cdt.finite_vertices_end(); ++itr) {
    //Rprintf("%f , %f\n", itr->point().x(), itr->point().y());
    xi[i] = itr->point().x();
    yi[i] = itr->point().y();
    i++;
  }


  Rprintf("Number of vertices after: %i\n", cdt.number_of_vertices());
  return Rcpp::List::create(Named("x") = xi , _["y"] = yi);
}

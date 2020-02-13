//#include <Rcpp.h>
//using namespace Rcpp;

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

void insert_mesh(int *n,
                 double *x_, double *y_,
                 int *i0, int *i1)
{
  CDT cdt;

  Vertex_handle vh0, vh1;

  for (int i = 0; i < n[0]; i++) {
   vh0 = cdt.insert(Point(x_[i0[i]], y_[i0[i]]));
    vh1 = cdt.insert(Point(x_[i1[i]], y_[i1[i]]));
    //cdt.insert_constraint(vh0,vh1);
  }
  std::cout << "points done\n";
  std::cout << "Number of vertices before: "
            << cdt.number_of_vertices() << std::endl;
  // make it conforming Delaunay
  CGAL::make_conforming_Delaunay_2(cdt);
  std::cout << "delaunay done\n";
  std::cout << "Number of vertices after make_conforming_Delaunay_2: "
            << cdt.number_of_vertices() << std::endl;
}

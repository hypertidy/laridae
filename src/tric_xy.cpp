#include <Rcpp.h>
using namespace Rcpp;


#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <cassert>
#include <iostream>
typedef CGAL::Exact_predicates_inexact_constructions_kernel K;
typedef CGAL::Triangulation_vertex_base_2<K>                     Vb;
typedef CGAL::Constrained_triangulation_face_base_2<K>           Fb;
typedef CGAL::Triangulation_data_structure_2<Vb,Fb>              TDS;
typedef CGAL::Exact_predicates_tag                               Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, TDS, Itag> CDT;
typedef CDT::Point          Point;

//' CGAL vertex index
//'
//' vertex index
//' @export
// [[Rcpp::export]]
IntegerVector ctri_xy(NumericVector x, NumericVector y) {

  CDT cdt;
  int npairs = x.length() - 1;
  for (int i = 0; i < npairs; ++i)
   cdt.insert_constraint( Point(x[i], y[i]), Point(x[i + 1], y[i + 1]));

  IntegerVector nf(1);
  nf[0] = cdt.number_of_faces() * 3;


  return nf;
}

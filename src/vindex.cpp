#include <Rcpp.h>
using namespace Rcpp;


#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_vertex_base_with_info_2.h>
#include <vector>

typedef CGAL::Exact_predicates_inexact_constructions_kernel            Kernel;
typedef CGAL::Triangulation_vertex_base_with_info_2<unsigned int, Kernel> Vb;
typedef CGAL::Triangulation_data_structure_2<Vb>                       Tds;
typedef CGAL::Delaunay_triangulation_2<Kernel, Tds>                    Delaunay;
typedef Kernel::Point_2                                                Point;

//' CGAL vertex index
//'
//' vertex index
//' @export
// [[Rcpp::export]]
IntegerVector vindex(NumericVector x, NumericVector y) {
  std::vector< std::pair<Point,unsigned> > points;
  for (int ipoint = 0; ipoint < x.length(); ipoint++){
    points.push_back( std::make_pair( Point(x[ipoint], y[ipoint]), ipoint ) );
  }
  Delaunay triangulation;
  triangulation.insert(points.begin(),points.end());

  IntegerVector vi(triangulation.number_of_vertices() * 3);
  int cnt = 0;
  for(Delaunay::Finite_faces_iterator fit = triangulation.finite_faces_begin();
      fit != triangulation.finite_faces_end(); ++fit) {
    Delaunay::Face_handle face = fit;
    vi[cnt    ] = face->vertex(0)->info();
    vi[cnt + 1] = face->vertex(1)->info();
    vi[cnt + 2] = face->vertex(2)->info();
    cnt = cnt + 3;
  }

  return vi;
}

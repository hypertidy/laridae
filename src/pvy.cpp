#include <Rcpp.h>
using namespace Rcpp;


#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_vertex_base_with_info_2.h>
#include <vector>

typedef CGAL::Exact_predicates_inexact_constructions_kernel            Kernel;
typedef CGAL::Triangulation_vertex_base_with_info_2<int, Kernel> Vb;
typedef CGAL::Triangulation_data_structure_2<Vb>                       Tds;
typedef CGAL::Delaunay_triangulation_2<Kernel, Tds>                    Delaunay;
typedef Kernel::Point_2                                                Point;

//' CGAL vertex index
//'
//' vertex index
//' @export
// [[Rcpp::export]]
IntegerVector pvy(NumericVector x, NumericVector y) {
  std::vector< std::pair<Point,int> > points;
  double xx = 0;
  double yy = 0;
   for (int idouble = 0; idouble < x.length(); idouble++){
      xx = x[idouble];
      yy = y[idouble];

     points.push_back( std::make_pair( Point(xx, yy), idouble ) );
  }
//  Point pp = Point(xx, yy);

 // for (int ipoint = 0; ipoint < x.length(); ipoint++){
  //  points.push_back( std::make_pair( Point(x[ipoint], y[ipoint]), ipoint ) );
  //}

//   points.push_back( std::make_pair( Point(0.0, 0.0), 0 ) );
//   points.push_back( std::make_pair( Point(0.0, 1.0), 1 ) );
//   points.push_back( std::make_pair( Point(1.0, 0.0), 2 ) );
//   points.push_back( std::make_pair( Point(1.0, 1.0), 3 ) );
//   points.push_back( std::make_pair( Point(2.0, 5.0), 4 ) );

  Delaunay triangulation;
  triangulation.insert(points.begin(),points.end());

   int vindex[triangulation.number_of_vertices() * 3];
   int facit;
    int cnt = 0;
    for(Delaunay::Finite_faces_iterator fit = triangulation.finite_faces_begin();
        fit != triangulation.finite_faces_end(); ++fit) {
      Delaunay::Face_handle face = fit;
      facit = face->vertex(0)->info();
      std::cout << facit << std::endl;
      //vindex[cnt    ] = (int)facit;
      //vindex[cnt + 1] = face->vertex(1)->info();
      //vindex[cnt + 2] = face->vertex(2)->info();
      cnt = cnt + 3;
    }

IntegerVector vi(triangulation.number_of_vertices() * 3);
  return vi;
}



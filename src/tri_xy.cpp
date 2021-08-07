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

typedef Tds::Vertex Vertex;
typedef Tds::Vertex_iterator Vertex_iterator;
typedef Tds::Face Face;
typedef Tds::Face_iterator Face_iterator;
typedef Face::Face_handle Face_handle;
typedef Face::Vertex_handle Fvertex_handle;

// [[Rcpp::export]]
IntegerVector tri_xy_cpp(NumericVector x, NumericVector y) {
  std::vector< std::pair<Point,int> > points;
  for (int ip = 0; ip < x.length(); ip++){
    points.push_back( std::make_pair( Point(x[ip], y[ip]), ip) );
  }

  Delaunay triangulation;

  triangulation.insert(points.begin(),points.end());
  //printf("number of vertices: %i\n", triangulation.number_of_vertices());
  //printf("number of faces: %i\n", triangulation.number_of_faces());
  IntegerVector vi(triangulation.number_of_faces() * 3);
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

// [[Rcpp::export]]

IntegerVector tri_xy1_cpp(NumericVector x, NumericVector y)
{
  std::vector< std::pair<Point,int> > points;
  for (int ipoint = 0; ipoint < x.length(); ipoint++){
    points.push_back( std::make_pair( Point(x[ipoint], y[ipoint]), ipoint) );
  }

  Delaunay triangulation;
  triangulation.insert (points.begin (), points.end ());

  Vertex v;
  Vertex_iterator it = triangulation.vertices_begin (),
                  beyond = triangulation.vertices_end ();
  IntegerVector vi(triangulation.number_of_faces() * 3);

  unsigned int cnt = 0;
  while (it != beyond) {
    vi [cnt++] = it->info();
    ++it;
  }

  return vi;
}

// [[Rcpp::export]]
IntegerVector tri_xy2_cpp(NumericVector x, NumericVector y)
{
  std::vector< std::pair<Point,int> > points;
  for (int ipoint = 0; ipoint < x.length(); ipoint++){
    points.push_back( std::make_pair( Point(x[ipoint], y[ipoint]), ipoint) );
  }

  Delaunay triangulation;
  triangulation.insert (points.begin (), points.end ());

  Face_iterator itf = triangulation.faces_begin (),
                beyondf = triangulation.faces_end ();
  Face face;
  Face_handle neighbour;
  Fvertex_handle fvertex;

  Vertex v;
  IntegerVector vi(triangulation.number_of_faces() * 3);
  Delaunay tr_reduced;
  int count = 0;
  bool is_finite;
  while (itf != beyondf)
  {
      face = *(itf++);
      is_finite = true;
      for (int i=0; i<3; i++) {
          fvertex = face.vertex (i);
          if (triangulation.is_infinite (fvertex))
              is_finite = false;
      }
      if (is_finite)
      {
          for (int i=0; i<3; i++)
          {
              //fvertex = face.vertex (i);
              v = *(face.vertex (i));
              vi [count++] = face.vertex(i)->info();
          }
      }
  }

  return vi;
}


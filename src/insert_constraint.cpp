// [[Rcpp::depends(cgalh)]]
#include <Rcpp.h>
using namespace Rcpp;

#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_conformer_2.h>
#include <CGAL/Delaunay_mesher_2.h>
#include <CGAL/Delaunay_mesh_face_base_2.h>
#include <CGAL/Delaunay_mesh_size_criteria_2.h>

#include <iostream>
typedef CGAL::Exact_predicates_inexact_constructions_kernel K;
typedef CGAL::Triangulation_vertex_base_2<K> Vb;
typedef CGAL::Delaunay_mesh_face_base_2<K> Fb;
typedef CGAL::Triangulation_data_structure_2<Vb, Fb> Tds;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, Tds> CDT;
typedef CGAL::Delaunay_mesh_size_criteria_2<CDT> Criteria;
typedef CGAL::Delaunay_mesher_2<CDT, Criteria> Mesher;
typedef CDT::Vertex_handle Vertex_handle;
typedef CDT::Point Point;

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

 Mesher mesher(cdt);

 //  mesher.refine_mesh();
 // Rprintf("Number of vertices after refine: %i\n", cdt.number_of_vertices());

  // std::cout << "Number of vertices: " << cdt.number_of_vertices() << std::endl;
  // std::cout << "Meshing with new criterias..." << std::endl;
  // // 0.125 is the default shape bound. It corresponds to abound 20.6 degree.
  // // 0.5 is the upper bound on the length of the longuest edge.
  // // See reference manual for Delaunay_mesh_size_traits_2<K>.
  mesher.set_criteria(Criteria(0.125, 0.5));
  mesher.refine_mesh();
  Rprintf("Number of vertices after refine criteria: %i\n", cdt.number_of_vertices());

  int mesh_faces_counter = 0;
  for(CDT::Finite_faces_iterator fit = cdt.finite_faces_begin();
      fit != cdt.finite_faces_end(); ++fit)
  {
    if(fit->is_in_domain()) {
//fit->vertex(0)->handle()->
    ++mesh_faces_counter;
    }
  }


 Rprintf("Number of faces: %i\n", mesh_faces_counter);

  // Vertex v;
  // Vertex_iterator it = cdt.vertices_begin (),
  //   beyond = cdt.vertices_end ();
  // NumericVector vi(cdt.number_of_vertices());
  //
  // unsigned int cnt = 0;
  // while (it != beyond) {
  //   vi [cnt++] = it.;
  //   ++it;
  // }
  //
  return 0;
}

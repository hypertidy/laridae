#include <iostream>
#include </usr/include/CGAL/Simple_cartesian.h>
typedef CGAL::Simple_cartesian<double> Kernel;
typedef Kernel::Point_2 Point_2;
typedef Kernel::Segment_2 Segment_2;


#include <Rcpp.h>

using namespace Rcpp;


//' CGAL test2
//'
//' test2 CGAL
//' @export
// [[Rcpp::export]]
IntegerVector pas()
  //Kernel_23/points_and_segment.cpp
{
  Point_2 p(1,1), q(10,10);
 // std::cout << "p = " << p << std::endl;
//  std::cout << "q = " << q.x() << " " << q.y() << std::endl;
  std::cout << "sqdist(p,q) = "
            << CGAL::squared_distance(p,q) << std::endl;

  Segment_2 s(p,q);
  Point_2 m(5, 9);

//std::cout << "m = " << m << std::endl;
std::cout << "m = " << m.x() << std::endl;
  std::cout << "sqdist(Segment_2(p,q), m) = "
            << CGAL::squared_distance(s,m) << std::endl;
  std::cout << "p, q, and m ";
  switch (CGAL::orientation(p,q,m)){
  case CGAL::COLLINEAR:
    std::cout << "are collinear\n";
    break;
  case CGAL::LEFT_TURN:
    std::cout << "make a left turn\n";
    break;
  case CGAL::RIGHT_TURN:
    std::cout << "make a right turn\n";
    break;
  }
  //std::cout << " midpoint(p,q) = " << CGAL::midpoint(p,q) << std::endl;
  std::cout << " midpoint(p,q) = " << CGAL::midpoint(p,q).x() << " " << CGAL::midpoint(p,q).y() << std::endl;
   IntegerVector xnumber(1);
   return xnumber;
}

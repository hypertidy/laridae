// Exact constructions for constrained triangulation, without refinement.
//
// The main handle (laridae.cpp) uses Epick: predicates are exact but a
// crossing of two constraints is constructed in double. Here the same
// Constrained_triangulation_plus_2 is instantiated on Epeck with
// Exact_intersections_tag, so a crossing is an exact rational. Each vertex is
// returned as its nearest double (correctly rounded, ties to even) plus the
// exact value as numerator and denominator strings, which is how an exact
// coordinate can live in a table (and travel to another CGAL-backed package)
// without an external pointer.
//
// With CGAL_DISABLE_GMP the exact number type is Boost.Multiprecision's
// rational, so this needs no system GMP.

#include <CGAL/Exact_predicates_exact_constructions_kernel.h>
#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Constrained_triangulation_plus_2.h>
#include <CGAL/Triangulation_vertex_base_with_info_2.h>
#include <CGAL/Constrained_triangulation_face_base_2.h>
#include <CGAL/Fraction_traits.h>

#include <cpp11.hpp>

#include <cmath>
#include <cstdint>
#include <cstring>
#include <map>
#include <sstream>
#include <string>
#include <type_traits>
#include <vector>

using namespace cpp11;
namespace writable = cpp11::writable;

namespace {

// vertex info that starts at 0 (CGAL leaves a plain int uninitialised)
struct Id {
  int id = 0;
  operator int() const { return id; }
  Id& operator=(int i) { id = i; return *this; }
};

template <class FT>
void decompose(const FT& v, std::string& num, std::string& den) {
  const auto e = CGAL::exact(v);
  typedef CGAL::Fraction_traits<std::decay_t<decltype(e)>> FTr;
  typename FTr::Numerator_type n;
  typename FTr::Denominator_type d;
  typename FTr::Decompose()(e, n, d);
  std::ostringstream sn, sd;
  sn << n;
  sd << d;
  num = sn.str();
  den = sd.str();
}

// Nearest double to an exact number, ties to even. CGAL::to_double() on a lazy
// exact value returns an approximation that can be an ulp or more away, so
// start there and step to the neighbouring double while that is closer,
// measuring the error exactly.
template <class ET>
double nearest_double(const ET& q) {
  double c = CGAL::to_double(q);
  if (!std::isfinite(c)) return c;
  auto err = [&q](double d) {
    ET t = q - ET(d);
    if (t < 0) t = -t;
    return t;
  };
  ET ec = err(c);
  for (;;) {
    const double up = std::nextafter(c, HUGE_VAL), dn = std::nextafter(c, -HUGE_VAL);
    const ET eu = err(up), ed = err(dn);
    if (eu < ec) { c = up; ec = eu; }
    else if (ed < ec) { c = dn; ec = ed; }
    else {
      // a tie with a neighbour: take the one with an even significand
      std::uint64_t bits;
      std::memcpy(&bits, &c, sizeof bits);
      if (bits & 1u) {
        if (eu == ec) return up;
        if (ed == ec) return dn;
      }
      return c;
    }
  }
}

template <class FT>
double to_nearest(const FT& v, std::true_type) { return nearest_double(CGAL::exact(v)); }
template <class FT>
double to_nearest(const FT& v, std::false_type) { return CGAL::to_double(v); }

template <class K, class Itag, bool Exact>
list run_cdt(doubles x, doubles y, integers s0, integers s1) {
  typedef CGAL::Triangulation_vertex_base_with_info_2<Id, K> Vb;
  typedef CGAL::Constrained_triangulation_face_base_2<K> Fb;
  typedef CGAL::Triangulation_data_structure_2<Vb, Fb> Tds;
  typedef CGAL::Constrained_Delaunay_triangulation_2<K, Tds, Itag> CDT;
  typedef CGAL::Constrained_triangulation_plus_2<CDT> CDTP;
  typedef typename CDTP::Point Point;
  typedef typename CDTP::Vertex_handle Vertex_handle;

  CDTP cdt;
  const int n = x.size();
  std::vector<Vertex_handle> vh(n);
  for (int i = 0; i < n; ++i) {
    vh[i] = cdt.insert(Point(x[i], y[i]));
    if (vh[i]->info() == 0) vh[i]->info() = i + 1;   // duplicates keep the first id
  }
  for (int k = 0; k < s0.size(); ++k) {
    cdt.insert_constraint(vh[s0[k] - 1], vh[s1[k] - 1]);
  }

  // rows: inputs first (by first id), then crossings in iteration order
  std::map<Vertex_handle, int> row;
  std::vector<Vertex_handle> order;
  for (int i = 0; i < n; ++i) if (!row.count(vh[i])) { row[vh[i]] = 0; order.push_back(vh[i]); }
  for (auto v = cdt.finite_vertices_begin(); v != cdt.finite_vertices_end(); ++v) {
    if (v->info() == 0) { row[v] = 0; order.push_back(v); }
  }
  const int nv = order.size();
  writable::doubles X(nv), Y(nv);
  writable::strings xn(nv), xd(nv), yn(nv), yd(nv), org(nv);
  for (int r = 0; r < nv; ++r) {
    Vertex_handle v = order[r];
    row[v] = r + 1;
    X[r] = to_nearest(v->point().x(), std::integral_constant<bool, Exact>());
    Y[r] = to_nearest(v->point().y(), std::integral_constant<bool, Exact>());
    org[r] = v->info() == 0 ? "crossing" : "input";
    if constexpr (Exact) {
      std::string a, b;
      decompose(v->point().x(), a, b); xn[r] = a; xd[r] = b;
      decompose(v->point().y(), a, b); yn[r] = a; yd[r] = b;
    } else {
      xn[r] = NA_STRING; xd[r] = NA_STRING; yn[r] = NA_STRING; yd[r] = NA_STRING;
    }
  }

  std::vector<int> t0, t1, t2;
  for (auto f = cdt.finite_faces_begin(); f != cdt.finite_faces_end(); ++f) {
    t0.push_back(row[f->vertex(0)]);
    t1.push_back(row[f->vertex(1)]);
    t2.push_back(row[f->vertex(2)]);
  }
  std::vector<int> e0, e1;
  for (auto e = cdt.finite_edges_begin(); e != cdt.finite_edges_end(); ++e) {
    if (!cdt.is_constrained(*e)) continue;
    int a = row[e->first->vertex(CDTP::cw(e->second))];
    int b = row[e->first->vertex(CDTP::ccw(e->second))];
    if (a > b) std::swap(a, b);
    e0.push_back(a);
    e1.push_back(b);
  }

  writable::data_frame vertices({"x"_nm = X, "y"_nm = Y,
                                 "x_num"_nm = xn, "x_den"_nm = xd,
                                 "y_num"_nm = yn, "y_den"_nm = yd,
                                 "origin"_nm = org});
  writable::integers a(t0.begin(), t0.end()), b(t1.begin(), t1.end()), c(t2.begin(), t2.end());
  writable::integers ea(e0.begin(), e0.end()), eb(e1.begin(), e1.end());
  writable::data_frame triangles({"v0"_nm = a, "v1"_nm = b, "v2"_nm = c});
  writable::data_frame segments({"v0"_nm = ea, "v1"_nm = eb});
  return writable::list({"vertices"_nm = vertices, "triangles"_nm = triangles,
                         "segments"_nm = segments});
}

} // namespace

[[cpp11::register]]
list lari_cdt_cpp(doubles x, doubles y, integers s0, integers s1, bool exact) {
  if (exact) {
    return run_cdt<CGAL::Exact_predicates_exact_constructions_kernel,
                   CGAL::Exact_intersections_tag, true>(x, y, s0, s1);
  }
  return run_cdt<CGAL::Exact_predicates_inexact_constructions_kernel,
                 CGAL::Exact_predicates_tag, false>(x, y, s0, s1);
}

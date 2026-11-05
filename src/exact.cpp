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
#include <algorithm>
#include <limits>
#include <map>
#include <queue>
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

// Constraint layer depth from the outside, Dijkstra over face adjacency:
// crossing a constrained edge costs the number of input segments covering it
// (or 1 when `distinct`), as in the main handle's depth_walk().
template <class CDTP>
std::map<typename CDTP::Face_handle, int> exact_depth(const CDTP& cdt, bool distinct) {
  typedef typename CDTP::Face_handle Face_handle;
  const int inf = std::numeric_limits<int>::max();
  std::map<Face_handle, int> out;
  for (auto f = cdt.all_faces_begin(); f != cdt.all_faces_end(); ++f) out[Face_handle(f)] = inf;
  if (cdt.dimension() < 2) return out;
  typedef std::pair<int, Face_handle> QE;
  auto cmp = [](const QE& a, const QE& b) { return a.first > b.first; };
  std::priority_queue<QE, std::vector<QE>, decltype(cmp)> q(cmp);
  for (auto f = cdt.all_faces_begin(); f != cdt.all_faces_end(); ++f) {
    if (cdt.is_infinite(Face_handle(f))) { out[Face_handle(f)] = 0; q.push(QE(0, Face_handle(f))); }
  }
  while (!q.empty()) {
    QE top = q.top(); q.pop();
    Face_handle f = top.second;
    if (top.first > out[f]) continue;
    for (int i = 0; i < 3; ++i) {
      Face_handle n = f->neighbor(i);
      int w = 0;
      if (f->is_constrained(i)) {
        w = (int)cdt.number_of_enclosing_constraints(f->vertex(CDTP::cw(i)), f->vertex(CDTP::ccw(i)));
        if (distinct && w > 0) w = 1;
      }
      const int d = top.first + w;
      if (d < out[n]) { out[n] = d; q.push(QE(d, n)); }
    }
  }
  return out;
}

// domain: 0 hull (all), 1 outer (depth > 0), 2 holes (odd depth)
bool exact_keep(int depth, int domain) {
  if (domain == 0) return true;
  if (domain == 1) return depth > 0;
  return depth % 2 == 1;
}

template <class K, class Itag, bool Exact>
list run_cdt(doubles x, doubles y, integers s0, integers s1, int domain) {
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
  typedef typename CDTP::Constraint_id Constraint_id;
  std::map<Constraint_id, int> seg_of;   // constraint -> input segment (1-based)
  for (int k = 0; k < s0.size(); ++k) {
    Vertex_handle a = vh[s0[k] - 1], b = vh[s1[k] - 1];
    if (a == b) continue;   // zero length: no constraint, no rows
    seg_of[cdt.insert_constraint(a, b)] = k + 1;
  }
  if (seg_of.empty()) domain = 0;   // no boundary to erase outside of

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

  typedef typename CDTP::Face_handle Face_handle;
  std::map<Face_handle, int> depth = exact_depth(cdt, false), depth_d = exact_depth(cdt, true);
  std::vector<int> t0, t1, t2, td, tdd;
  if (cdt.dimension() == 2) {
    for (auto f = cdt.finite_faces_begin(); f != cdt.finite_faces_end(); ++f) {
      const int d = depth[Face_handle(f)];
      if (!exact_keep(d, domain)) continue;
      t0.push_back(row[f->vertex(0)]);
      t1.push_back(row[f->vertex(1)]);
      t2.push_back(row[f->vertex(2)]);
      td.push_back(d);
      tdd.push_back(depth_d[Face_handle(f)]);
    }
  }
  // constraint edges, v0 < v1 by row, with every covering input segment
  // (edge_sources, mesh spec v0.2): CGAL's contexts list each enclosing
  // constraint, which runs forward when its current vertex is the edge's v0
  std::vector<int> e0, e1, esg, ecn, es_edge, es_seg, es_fwd;
  std::vector<std::pair<int, int> > here;
  for (auto e = cdt.finite_edges_begin(); e != cdt.finite_edges_end(); ++e) {
    if (!cdt.is_constrained(*e)) continue;
    Vertex_handle va = e->first->vertex(CDTP::cw(e->second));
    Vertex_handle vb = e->first->vertex(CDTP::ccw(e->second));
    if (row[va] > row[vb]) std::swap(va, vb);
    here.clear();
    for (auto ctx = cdt.contexts_begin(va, vb); ctx != cdt.contexts_end(va, vb); ++ctx) {
      auto it = seg_of.find(ctx->id());
      if (it != seg_of.end()) here.push_back(std::make_pair(it->second, *ctx->current() == va ? 1 : 0));
    }
    if (here.empty()) continue;
    std::sort(here.begin(), here.end());
    e0.push_back(row[va]);
    e1.push_back(row[vb]);
    esg.push_back(here.front().first);
    ecn.push_back((int)here.size());
    for (const auto& h : here) {
      es_edge.push_back((int)e0.size());
      es_seg.push_back(h.first);
      es_fwd.push_back(h.second);
    }
  }

  writable::data_frame vertices({"x"_nm = X, "y"_nm = Y,
                                 "x_num"_nm = xn, "x_den"_nm = xd,
                                 "y_num"_nm = yn, "y_den"_nm = yd,
                                 "origin"_nm = org});
  writable::integers a(t0.begin(), t0.end()), b(t1.begin(), t1.end()), c(t2.begin(), t2.end()),
    d(td.begin(), td.end()), dd(tdd.begin(), tdd.end());
  writable::integers ea(e0.begin(), e0.end()), eb(e1.begin(), e1.end()),
    sg(esg.begin(), esg.end()), cn(ecn.begin(), ecn.end());
  writable::integers ee(es_edge.begin(), es_edge.end()), ss(es_seg.begin(), es_seg.end());
  writable::logicals ff(es_fwd.size());
  for (std::size_t i = 0; i < es_fwd.size(); ++i) ff[i] = es_fwd[i] ? TRUE : FALSE;
  writable::data_frame triangles({"v0"_nm = a, "v1"_nm = b, "v2"_nm = c,
                                  "depth"_nm = d, "depth_distinct"_nm = dd});
  writable::data_frame segments({"v0"_nm = ea, "v1"_nm = eb, "segment"_nm = sg, "count"_nm = cn});
  writable::data_frame edge_sources({"edge"_nm = ee, "segment"_nm = ss, "forward"_nm = ff});
  return writable::list({"vertices"_nm = vertices, "triangles"_nm = triangles,
                         "segments"_nm = segments, "edge_sources"_nm = edge_sources});
}

} // namespace

[[cpp11::register]]
list lari_cdt_cpp(doubles x, doubles y, integers s0, integers s1, bool exact, int domain) {
  if (exact) {
    return run_cdt<CGAL::Exact_predicates_exact_constructions_kernel,
                   CGAL::Exact_intersections_tag, true>(x, y, s0, s1, domain);
  }
  return run_cdt<CGAL::Exact_predicates_inexact_constructions_kernel,
                 CGAL::Exact_predicates_tag, false>(x, y, s0, s1, domain);
}

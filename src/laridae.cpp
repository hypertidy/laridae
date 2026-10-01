// laridae: CGAL constrained triangulation and Mesh_2 refinement behind a
// persistent handle. All CGAL templates are instantiated in this one
// translation unit; the exported surface is a handful of plain functions on
// an external pointer.
//
// Kernel: Exact_predicates_inexact_constructions_kernel (Epick). Predicates
// are exact, constructions (crossing points, circumcentres) are doubles, so
// no GMP is needed.

#include <cpp11.hpp>

#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Constrained_triangulation_plus_2.h>
#include <CGAL/Triangulation_vertex_base_with_info_2.h>
#include <CGAL/Triangulation_face_base_with_info_2.h>
#include <CGAL/Delaunay_mesh_vertex_base_2.h>
#include <CGAL/Delaunay_mesh_face_base_2.h>
#include <CGAL/Delaunay_mesher_2.h>
#include <CGAL/Mesh_2/Face_badness.h>

#include <cmath>
#include <functional>
#include <limits>
#include <map>
#include <memory>
#include <queue>
#include <string>
#include <utility>
#include <vector>

using namespace cpp11;
namespace writable = cpp11::writable;

namespace {

typedef CGAL::Exact_predicates_inexact_constructions_kernel K;
// vertex info: stable id (1-based), 0 = not yet adopted by the handle. A
// plain int would be left uninitialised on vertices CGAL creates itself.
struct Vid {
  int id = 0;
  Vid() = default;
  Vid& operator=(int i) { id = i; return *this; }
  operator int() const { return id; }
};
typedef CGAL::Delaunay_mesh_vertex_base_2<K> Vmb;
typedef CGAL::Triangulation_vertex_base_with_info_2<Vid, K, Vmb> Vb;
// face info: constraint depth scratch
typedef CGAL::Triangulation_face_base_with_info_2<int, K> Fib;
typedef CGAL::Constrained_triangulation_face_base_2<K, Fib> Cfb;
typedef CGAL::Delaunay_mesh_face_base_2<K, Cfb> Fb;
typedef CGAL::Triangulation_data_structure_2<Vb, Fb> Tds;
typedef CGAL::Exact_predicates_tag Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, Tds, Itag> CDT;
typedef CGAL::Constrained_triangulation_plus_2<CDT> CDTP;

typedef CDTP::Point Point;
typedef CDTP::Vertex_handle Vertex_handle;
typedef CDTP::Face_handle Face_handle;
typedef CDTP::Edge Edge;
typedef CDTP::Constraint_id Constraint_id;

enum Origin { ORIGIN_INPUT = 0, ORIGIN_CROSSING = 1, ORIGIN_STEINER = 2 };
enum Domain { DOMAIN_HULL = 0, DOMAIN_OUTER = 1, DOMAIN_HOLES = 2 };

// ---------------------------------------------------------------------------
// Sizing: a target maximum triangle area as a function of position. Either a
// constant, a regular grid (nearest cell), or an R function called per face.

struct Sizing {
  double max_area = -1;                 // constant bound, <= 0 for none
  // grid, image() convention: z is nx by ny, x/y are cell centres
  std::vector<double> gx, gy, gz;
  // R callback, function(x, y) returning a local max area
  bool has_fun = false;
  cpp11::sexp fun;

  bool active() const { return max_area > 0 || !gz.empty() || has_fun; }

  double grid_at(double x, double y) const {
    const std::size_t nx = gx.size(), ny = gy.size();
    if (nx == 0 || ny == 0) return NA_REAL;
    const double dx = nx > 1 ? (gx[nx - 1] - gx[0]) / (nx - 1) : 1;
    const double dy = ny > 1 ? (gy[ny - 1] - gy[0]) / (ny - 1) : 1;
    const double fi = std::floor((x - gx[0]) / dx + 0.5);
    const double fj = std::floor((y - gy[0]) / dy + 0.5);
    if (fi < 0 || fj < 0 || fi >= (double)nx || fj >= (double)ny) return NA_REAL;
    return gz[(std::size_t)fi + nx * (std::size_t)fj];
  }

  // local bound at (x, y); <= 0 or NA means unbounded
  double at(double x, double y) const {
    double out = max_area > 0 ? max_area : std::numeric_limits<double>::infinity();
    if (!gz.empty()) {
      const double g = grid_at(x, y);
      if (!ISNAN(g) && g > 0 && g < out) out = g;
    }
    if (has_fun) {
      cpp11::function f(fun);
      const double v = cpp11::as_cpp<double>(f(x, y));
      if (!ISNAN(v) && v > 0 && v < out) out = v;
    }
    return out;
  }
};

// ---------------------------------------------------------------------------
// Meshing criteria (MeshingCriteria_2): smallest angle and local area, with an
// edge-length floor below which a face is never considered bad. The floor is
// what stops Ruppert refinement cascading into sharp input corners.

struct Lari_criteria {
  double sine2_bound = 0;   // squared sine of the minimum angle, 0 for none
  double min_edge2 = 0;     // squared edge-length floor
  std::shared_ptr<Sizing> sizing = std::make_shared<Sizing>();

  // first: squared minimum sine; second: area / local bound (> 1 is too big)
  struct Quality : public std::pair<double, double> {
    typedef std::pair<double, double> Base;
    Quality() : Base() {}
    Quality(double s, double z) : Base(s, z) {}
    const double& size() const { return second; }
    const double& sine() const { return first; }
    bool operator<(const Quality& q) const {
      if (size() > 1) return q.size() > 1 ? size() > q.size() : true;
      if (q.size() > 1) return false;
      return sine() < q.sine();
    }
  };

  struct Measure {
    double area, sine2, short2, area_bound;
  };

  static Measure measure(const Face_handle& fh, const Sizing* sz) {
    const Point& pa = fh->vertex(0)->point();
    const Point& pb = fh->vertex(1)->point();
    const Point& pc = fh->vertex(2)->point();
    const double a = CGAL::squared_distance(pb, pc);
    const double b = CGAL::squared_distance(pc, pa);
    const double c = CGAL::squared_distance(pa, pb);
    const double area = std::fabs(CGAL::area(pa, pb, pc));
    const double area2 = area * area;
    double sine2;
    // sin(angle opposite the shortest edge) = 2 area / (product of the others)
    if (a < b) sine2 = a < c ? area2 / (b * c) : area2 / (a * b);
    else       sine2 = b < c ? area2 / (a * c) : area2 / (a * b);
    sine2 *= 4;
    Measure m;
    m.area = area;
    m.sine2 = sine2;
    m.short2 = std::min(a, std::min(b, c));
    m.area_bound = std::numeric_limits<double>::infinity();
    if (sz && sz->active()) {
      const double cx = (pa.x() + pb.x() + pc.x()) / 3.0;
      const double cy = (pa.y() + pb.y() + pc.y()) / 3.0;
      m.area_bound = sz->at(cx, cy);
    }
    return m;
  }

  // holds copies, so it never points into a criteria object that moved
  class Is_bad {
    double sine2_bound, min_edge2;
    std::shared_ptr<Sizing> sizing;
  public:
    explicit Is_bad(const Lari_criteria& c)
      : sine2_bound(c.sine2_bound), min_edge2(c.min_edge2), sizing(c.sizing) {}
    CGAL::Mesh_2::Face_badness operator()(const Quality q) const {
      if (q.size() > 1) return CGAL::Mesh_2::IMPERATIVELY_BAD;
      if (q.sine() < sine2_bound) return CGAL::Mesh_2::BAD;
      return CGAL::Mesh_2::NOT_BAD;
    }
    CGAL::Mesh_2::Face_badness operator()(const Face_handle& fh, Quality& q) const {
      const Measure m = measure(fh, sizing.get());
      q.first = m.sine2;
      q.second = std::isfinite(m.area_bound) ? m.area / m.area_bound : 0;
      if (m.short2 < min_edge2) {
        // below the floor: never bad, so the refiner leaves it alone
        q.first = 1; q.second = 0;
        return CGAL::Mesh_2::NOT_BAD;
      }
      return (*this)(q);
    }
  };

  Is_bad is_bad_object() const { return Is_bad(*this); }
};

typedef CGAL::Delaunay_mesher_2<CDTP, Lari_criteria> Mesher;

// ---------------------------------------------------------------------------

struct Refine_settings {
  bool set = false;
  double min_angle = -1, max_area = -1, min_edge_length = 0;
  int domain = DOMAIN_OUTER;
  std::vector<Point> seeds;
};

struct Unrefined {
  bool set = false;
  int bad = 0, short_edges = 0, sharp_fixed_corner = 0, circumcenter_outside = 0;
  int inserted = 0;
  bool budget_hit = false;
};

struct Mesh {
  CDTP cdt;
  // id - 1 -> handle; a default (null) handle is a tombstone
  std::vector<Vertex_handle> vh;
  std::vector<int> origin;
  std::vector<std::string> attr_names;
  std::vector<std::vector<double> > attr;   // attr[col][id - 1]
  // segment id - 1 -> constraint; null is removed
  std::vector<Constraint_id> seg;
  std::map<Constraint_id, int> seg_of;

  Lari_criteria criteria;
  Refine_settings settings;
  Unrefined unrefined;
  std::unique_ptr<Mesher> mesher;

  int ncol() const { return (int)attr_names.size(); }
  void invalidate() { mesher.reset(); }
};

typedef cpp11::external_pointer<Mesh> Mesh_ptr;

Mesh* get_mesh(SEXP xp) {
  Mesh_ptr p(xp);
  if (p.get() == nullptr) cpp11::stop("laridae handle is no longer valid (was it saved and reloaded?)");
  return p.get();
}

// A lightweight copy of the triangulation used to interpolate attributes onto
// vertices created by an operation (crossings, Steiner points).
struct Snapshot {
  CDT tr;
  bool active = false;
};

void take_snapshot(const Mesh& m, Snapshot& s) {
  s.active = m.ncol() > 0 && m.cdt.number_of_vertices() > 0;
  if (s.active) s.tr = static_cast<const CDT&>(m.cdt);
}

void interpolate_attr(Mesh& m, const Snapshot& s, const Point& p, int id) {
  const int nc = m.ncol();
  for (int k = 0; k < nc; ++k) m.attr[k][id - 1] = NA_REAL;
  if (!s.active) return;
  const CDT& tr = s.tr;
  if (tr.dimension() < 1) {
    const int src = tr.finite_vertices_begin()->info();
    for (int k = 0; k < nc; ++k) m.attr[k][id - 1] = m.attr[k][src - 1];
    return;
  }
  CDT::Locate_type lt; int li;
  CDT::Face_handle f = tr.locate(p, lt, li);
  if (tr.dimension() == 2 && !tr.is_infinite(f)) {
    const Point& a = f->vertex(0)->point();
    const Point& b = f->vertex(1)->point();
    const Point& c = f->vertex(2)->point();
    const double A = CGAL::area(a, b, c);
    if (A != 0) {
      const double w0 = CGAL::area(p, b, c) / A;
      const double w1 = CGAL::area(a, p, c) / A;
      const double w2 = 1.0 - w0 - w1;
      const int i0 = f->vertex(0)->info(), i1 = f->vertex(1)->info(), i2 = f->vertex(2)->info();
      for (int k = 0; k < nc; ++k) {
        m.attr[k][id - 1] = w0 * m.attr[k][i0 - 1] + w1 * m.attr[k][i1 - 1] + w2 * m.attr[k][i2 - 1];
      }
      return;
    }
  }
  // outside the hull (or degenerate): nearest vertex
  double best = std::numeric_limits<double>::infinity();
  int src = 0;
  for (CDT::Finite_vertices_iterator v = tr.finite_vertices_begin(); v != tr.finite_vertices_end(); ++v) {
    const double d = CGAL::squared_distance(v->point(), p);
    if (d < best) { best = d; src = v->info(); }
  }
  if (src > 0) for (int k = 0; k < nc; ++k) m.attr[k][id - 1] = m.attr[k][src - 1];
}

int new_id(Mesh& m, Vertex_handle v, int origin) {
  m.vh.push_back(v);
  m.origin.push_back(origin);
  for (auto& col : m.attr) col.push_back(NA_REAL);
  const int id = (int)m.vh.size();
  v->info() = id;
  return id;
}

// give ids to every vertex the triangulation created on its own
int adopt_new_vertices(Mesh& m, const Snapshot& s, int origin) {
  int n = 0;
  for (CDTP::Finite_vertices_iterator v = m.cdt.finite_vertices_begin(); v != m.cdt.finite_vertices_end(); ++v) {
    if (v->info() == 0) {
      const int id = new_id(m, v, origin);
      interpolate_attr(m, s, v->point(), id);
      ++n;
    }
  }
  return n;
}

Vertex_handle handle_of(const Mesh& m, int id) {
  if (id < 1 || id > (int)m.vh.size() || m.vh[id - 1] == Vertex_handle())
    cpp11::stop("vertex id %d is not in the mesh", id);
  return m.vh[id - 1];
}

// ---------------------------------------------------------------------------
// Depth: constraint crossings from the outside. Dijkstra over face adjacency
// where crossing a constrained edge costs the number of input segments that
// cover it (so coincident boundaries count once per segment, as CDT does).

void compute_depth(CDTP& cdt) {
  const int inf = std::numeric_limits<int>::max();
  for (CDTP::All_faces_iterator f = cdt.all_faces_begin(); f != cdt.all_faces_end(); ++f) f->info() = inf;
  if (cdt.dimension() < 2) return;
  typedef std::pair<int, Face_handle> QE;
  auto cmp = [](const QE& a, const QE& b) { return a.first > b.first; };
  std::priority_queue<QE, std::vector<QE>, decltype(cmp)> q(cmp);
  for (CDTP::All_faces_iterator f = cdt.all_faces_begin(); f != cdt.all_faces_end(); ++f) {
    if (cdt.is_infinite(f)) { f->info() = 0; q.push(QE(0, f)); }
  }
  while (!q.empty()) {
    QE top = q.top(); q.pop();
    Face_handle f = top.second;
    if (top.first > f->info()) continue;
    for (int i = 0; i < 3; ++i) {
      Face_handle n = f->neighbor(i);
      int w = 0;
      if (f->is_constrained(i)) {
        Vertex_handle va = f->vertex(CDTP::cw(i)), vb = f->vertex(CDTP::ccw(i));
        w = (int)cdt.number_of_enclosing_constraints(va, vb);
        if (w < 1) w = 1;
      }
      const int d = top.first + w;
      if (d < n->info()) { n->info() = d; q.push(QE(d, n)); }
    }
  }
}

bool keep_face(int depth, int domain) {
  if (domain == DOMAIN_HULL) return true;
  if (domain == DOMAIN_OUTER) return depth > 0;
  return depth % 2 == 1;
}

bool has_constraints(const Mesh& m) {
  for (const auto& c : m.seg) if (c != Constraint_id()) return true;
  return false;
}

int effective_domain(const Mesh& m, int domain) {
  return has_constraints(m) ? domain : (int)DOMAIN_HULL;
}

// ---------------------------------------------------------------------------
// Refinement

void mark_domain(Mesh& m) {
  CDTP& cdt = m.cdt;
  compute_depth(cdt);
  const int domain = effective_domain(m, m.settings.domain);
  for (CDTP::All_faces_iterator f = cdt.all_faces_begin(); f != cdt.all_faces_end(); ++f) {
    f->set_in_domain(!cdt.is_infinite(f) && keep_face(f->info(), domain));
  }
}

void make_mesher(Mesh& m) {
  m.mesher.reset(new Mesher(m.cdt, m.criteria));
  if (!m.settings.seeds.empty()) {
    // CGAL semantics: seeds mark regions (holes) that are not meshed
    m.mesher->set_seeds(m.settings.seeds.begin(), m.settings.seeds.end(), false, false);
    m.mesher->init(false);
  } else {
    mark_domain(m);
    m.mesher->init(true);
  }
}

bool sharp_corner(const CDTP& cdt, Vertex_handle v, double sine2_bound) {
  // two constrained edges at v meeting at an angle below the bound
  std::vector<Point> nb;
  CDTP::Edge_circulator ec = cdt.incident_edges(v), done(ec);
  if (ec == nullptr) return false;
  do {
    if (!cdt.is_infinite(ec) && cdt.is_constrained(*ec)) {
      Face_handle f = ec->first; int i = ec->second;
      Vertex_handle a = f->vertex(CDTP::cw(i)), b = f->vertex(CDTP::ccw(i));
      nb.push_back(a == v ? b->point() : a->point());
    }
  } while (++ec != done);
  if (nb.size() < 2) return false;
  const double lim = std::max(sine2_bound, 0.25);  // 30 degrees at least
  const Point& p = v->point();
  for (std::size_t i = 0; i < nb.size(); ++i) {
    for (std::size_t j = i + 1; j < nb.size(); ++j) {
      const double ux = nb[i].x() - p.x(), uy = nb[i].y() - p.y();
      const double wx = nb[j].x() - p.x(), wy = nb[j].y() - p.y();
      const double cr = ux * wy - uy * wx, dt = ux * wx + uy * wy;
      const double s2 = cr * cr / ((ux * ux + uy * uy) * (wx * wx + wy * wy));
      if (dt > 0 && s2 < lim) return true;
    }
  }
  return false;
}

void report_unrefined(Mesh& m) {
  Unrefined& u = m.unrefined;
  u.bad = u.short_edges = u.sharp_fixed_corner = u.circumcenter_outside = 0;
  const Lari_criteria& c = m.criteria;
  CDTP& cdt = m.cdt;
  for (CDTP::Finite_faces_iterator f = cdt.finite_faces_begin(); f != cdt.finite_faces_end(); ++f) {
    if (!f->is_in_domain()) continue;
    const Lari_criteria::Measure ms = Lari_criteria::measure(f, c.sizing.get());
    const bool too_big = std::isfinite(ms.area_bound) && ms.area > ms.area_bound;
    const bool too_sharp = ms.sine2 < c.sine2_bound;
    if (!too_big && !too_sharp) continue;
    ++u.bad;
    if (ms.short2 < c.min_edge2) ++u.short_edges;
    bool sharp = false;
    for (int i = 0; i < 3 && !sharp; ++i) sharp = sharp_corner(cdt, f->vertex(i), c.sine2_bound);
    if (sharp) ++u.sharp_fixed_corner;
    const Point cc = CGAL::circumcenter(f->vertex(0)->point(), f->vertex(1)->point(), f->vertex(2)->point());
    Face_handle g = cdt.locate(cc, f);
    if (cdt.is_infinite(g) || !g->is_in_domain()) ++u.circumcenter_outside;
  }
}

// run the mesher, at most `budget` new vertices (< 0 for no limit)
int run_mesher(Mesh& m, long budget, bool step_only) {
  Snapshot s;
  take_snapshot(m, s);
  // Mesh_2 needs a constrained boundary: to mesh the convex hull, constrain
  // its edges for the duration of this call (hidden from the tables)
  std::vector<Constraint_id> hull;
  if (m.settings.seeds.empty() && effective_domain(m, m.settings.domain) == DOMAIN_HULL) {
    std::vector<std::pair<Vertex_handle, Vertex_handle> > he;
    CDTP::Face_circulator fc = m.cdt.incident_faces(m.cdt.infinite_vertex()), done(fc);
    do {
      const int i = fc->index(m.cdt.infinite_vertex());
      he.push_back(std::make_pair(fc->vertex(CDTP::ccw(i)), fc->vertex(CDTP::cw(i))));
    } while (++fc != done);
    m.mesher.reset();
    for (const auto& e : he) hull.push_back(m.cdt.insert_constraint(e.first, e.second));
  }
  if (!m.mesher) make_mesher(m);
  const std::size_t n0 = m.cdt.number_of_vertices();
  m.unrefined.budget_hit = false;
  if (budget < 0 && !step_only) {
    m.mesher->refine_mesh();
  } else {
    while ((long)(m.cdt.number_of_vertices() - n0) < budget) {
      if (!m.mesher->step_by_step_refine_mesh()) break;
    }
    m.unrefined.budget_hit = !m.mesher->is_refinement_done();
  }
  const int n = adopt_new_vertices(m, s, ORIGIN_STEINER);
  m.unrefined.inserted = n;
  report_unrefined(m);
  m.unrefined.set = true;
  if (!hull.empty()) {
    m.mesher.reset();
    for (const auto& c : hull) m.cdt.remove_constraint(c);
  }
  return n;
}

// Crossing vertices: the mean over the segments through them of the linear
// interpolation between that segment's end vertices.
void interpolate_crossings(Mesh& m, int first_id) {
  const int nc = m.ncol();
  if (nc == 0 || first_id > (int)m.vh.size()) return;
  std::map<int, std::vector<double> > sum;
  std::map<int, int> count;
  for (const auto& cid : m.seg) {
    if (cid == Constraint_id()) continue;
    auto b = m.cdt.vertices_in_constraint_begin(cid);
    auto e = m.cdt.vertices_in_constraint_end(cid);
    Vertex_handle va = *b, vb = *std::prev(e);
    const int ia = va->info(), ib = vb->info();
    const double dx = vb->point().x() - va->point().x(), dy = vb->point().y() - va->point().y();
    const double len2 = dx * dx + dy * dy;
    for (auto it = b; it != e; ++it) {
      const int id = (*it)->info();
      if (id < first_id || m.origin[id - 1] != ORIGIN_CROSSING || len2 == 0) continue;
      const double t = ((*it)->point().x() - va->point().x()) * dx / len2 +
                       ((*it)->point().y() - va->point().y()) * dy / len2;
      std::vector<double>& acc = sum[id];
      if (acc.empty()) acc.assign(nc, 0.0);
      for (int k = 0; k < nc; ++k) acc[k] += (1 - t) * m.attr[k][ia - 1] + t * m.attr[k][ib - 1];
      ++count[id];
    }
  }
  for (const auto& kv : sum) {
    for (int k = 0; k < nc; ++k) m.attr[k][kv.first - 1] = kv.second[k] / count[kv.first];
  }
}

// ---------------------------------------------------------------------------
// Tables

writable::data_frame vertex_table(const Mesh& m, std::vector<int>& row_of) {
  row_of.assign(m.vh.size() + 1, 0);
  int nv = 0;
  for (std::size_t i = 0; i < m.vh.size(); ++i) if (m.vh[i] != Vertex_handle()) row_of[i + 1] = ++nv;
  writable::doubles x(nv), y(nv);
  writable::integers id(nv), org(nv);
  std::vector<writable::doubles> cols;
  for (int k = 0; k < m.ncol(); ++k) cols.push_back(writable::doubles(nv));
  for (std::size_t i = 0; i < m.vh.size(); ++i) {
    const int r = row_of[i + 1] - 1;
    if (r < 0) continue;
    x[r] = m.vh[i]->point().x();
    y[r] = m.vh[i]->point().y();
    id[r] = (int)i + 1;
    org[r] = m.origin[i];
    for (int k = 0; k < m.ncol(); ++k) cols[k][r] = m.attr[k][i];
  }
  writable::list out;
  writable::strings nms;
  out.push_back(x); nms.push_back("x");
  out.push_back(y); nms.push_back("y");
  for (int k = 0; k < m.ncol(); ++k) { out.push_back(cols[k]); nms.push_back(m.attr_names[k]); }
  out.push_back(org); nms.push_back("origin");
  out.push_back(id); nms.push_back("id");
  out.names() = nms;
  return writable::data_frame(std::move(out));
}

writable::data_frame triangle_table(Mesh& m, const std::vector<int>& row_of, int domain) {
  CDTP& cdt = m.cdt;
  compute_depth(cdt);
  domain = effective_domain(m, domain);
  std::vector<int> v0, v1, v2, dep;
  if (cdt.dimension() == 2) {
    for (CDTP::Finite_faces_iterator f = cdt.finite_faces_begin(); f != cdt.finite_faces_end(); ++f) {
      if (!keep_face(f->info(), domain)) continue;
      v0.push_back(row_of[f->vertex(0)->info()]);
      v1.push_back(row_of[f->vertex(1)->info()]);
      v2.push_back(row_of[f->vertex(2)->info()]);
      dep.push_back(f->info());
    }
  }
  writable::integers a(v0.begin(), v0.end()), b(v1.begin(), v1.end()), c(v2.begin(), v2.end()),
    d(dep.begin(), dep.end());
  return writable::data_frame({"v0"_nm = a, "v1"_nm = b, "v2"_nm = c, "depth"_nm = d});
}

writable::data_frame segment_table(const Mesh& m, const std::vector<int>& row_of) {
  const CDTP& cdt = m.cdt;
  std::vector<int> v0, v1, sid, cnt;
  for (CDTP::Finite_edges_iterator e = cdt.finite_edges_begin(); e != cdt.finite_edges_end(); ++e) {
    if (!cdt.is_constrained(*e)) continue;
    Vertex_handle va = e->first->vertex(CDTP::cw(e->second));
    Vertex_handle vb = e->first->vertex(CDTP::ccw(e->second));
    if (va->info() > vb->info()) std::swap(va, vb);
    int lowest = std::numeric_limits<int>::max(), n = 0;
    for (auto ctx = cdt.contexts_begin(va, vb); ctx != cdt.contexts_end(va, vb); ++ctx) {
      auto it = m.seg_of.find(ctx->id());
      if (it != m.seg_of.end() && it->second < lowest) lowest = it->second;
      ++n;
    }
    v0.push_back(row_of[va->info()]);
    v1.push_back(row_of[vb->info()]);
    sid.push_back(lowest == std::numeric_limits<int>::max() ? NA_INTEGER : lowest);
    cnt.push_back(n);
  }
  writable::integers a(v0.begin(), v0.end()), b(v1.begin(), v1.end()),
    s(sid.begin(), sid.end()), c(cnt.begin(), cnt.end());
  return writable::data_frame({"v0"_nm = a, "v1"_nm = b, "segment"_nm = s, "count"_nm = c});
}

} // namespace

// ---------------------------------------------------------------------------
// Registered functions

[[cpp11::register]]
SEXP lari_new_cpp(strings attr_names) {
  Mesh* m = new Mesh();
  for (R_xlen_t k = 0; k < attr_names.size(); ++k) {
    m->attr_names.push_back(std::string(attr_names[k]));
    m->attr.push_back(std::vector<double>());
  }
  Mesh_ptr p(m);
  return p;
}

[[cpp11::register]]
strings lari_attr_names_cpp(SEXP xp) {
  Mesh* m = get_mesh(xp);
  writable::strings out;
  for (const auto& s : m->attr_names) out.push_back(s);
  return out;
}

[[cpp11::register]]
integers lari_add_points_cpp(SEXP xp, doubles x, doubles y, doubles_matrix<> PA) {
  Mesh* m = get_mesh(xp);
  m->invalidate();
  const R_xlen_t n = x.size();
  const int nc = m->ncol();
  if (nc > 0 && (PA.nrow() != n || PA.ncol() != nc)) cpp11::stop("PA must have one row per point and %d columns", nc);
  Snapshot s;
  take_snapshot(*m, s);
  writable::integers ids(n);
  Vertex_handle hint;
  for (R_xlen_t i = 0; i < n; ++i) {
    if (ISNAN(x[i]) || ISNAN(y[i])) cpp11::stop("missing coordinates are not allowed");
    Point p(x[i], y[i]);
    Vertex_handle v = hint == Vertex_handle() ? m->cdt.insert(p) : m->cdt.insert(p, hint->face());
    hint = v;
    if (v->info() == 0) {
      const int id = new_id(*m, v, ORIGIN_INPUT);
      for (int k = 0; k < nc; ++k) m->attr[k][id - 1] = PA(i, k);
    }
    ids[i] = v->info();
  }
  // a point landing on a constraint splits it but adds no other vertex;
  // anything else new (none expected) is adopted for safety
  adopt_new_vertices(*m, s, ORIGIN_CROSSING);
  return ids;
}

[[cpp11::register]]
integers lari_add_segments_cpp(SEXP xp, integers s0, integers s1) {
  Mesh* m = get_mesh(xp);
  m->invalidate();
  const R_xlen_t n = s0.size();
  Snapshot s;
  take_snapshot(*m, s);
  writable::integers out(n);
  const int first_id = (int)m->vh.size() + 1;
  for (R_xlen_t i = 0; i < n; ++i) {
    Vertex_handle a = handle_of(*m, s0[i]), b = handle_of(*m, s1[i]);
    if (a == b) { out[i] = NA_INTEGER; continue; }
    Constraint_id cid = m->cdt.insert_constraint(a, b);
    m->seg.push_back(cid);
    const int sid = (int)m->seg.size();
    m->seg_of[cid] = sid;
    out[i] = sid;
  }
  adopt_new_vertices(*m, s, ORIGIN_CROSSING);
  interpolate_crossings(*m, first_id);
  return out;
}

namespace {
// remove crossing vertices that are no longer a crossing: no constraint ends
// there and at most one constraint passes through
void drop_free_crossings(Mesh& m) {
  bool again = true;
  while (again) {
    again = false;
    for (std::size_t i = 0; i < m.vh.size() && !again; ++i) {
      Vertex_handle v = m.vh[i];
      if (v == Vertex_handle() || m.origin[i] != ORIGIN_CROSSING) continue;
      if (m.cdt.are_there_incident_constraints(v)) {
        int through = 0, hit = 0;
        bool endpoint = false;
        for (int k = 1; k <= (int)m.seg.size(); ++k) {
          Constraint_id cid = m.seg[k - 1];
          if (cid == Constraint_id()) continue;
          auto b = m.cdt.vertices_in_constraint_begin(cid);
          auto e = m.cdt.vertices_in_constraint_end(cid);
          if (*b == v || *std::prev(e) == v) { endpoint = true; break; }
          for (auto it = b; it != e; ++it) if (*it == v) { ++through; hit = k; break; }
        }
        if (endpoint || through > 1) continue;
        if (through == 1) {
          // v sits exactly on the one remaining segment, so reinserting that
          // segment would pass through it again: take the segment out,
          // remove v, put the segment back under the same id
          Constraint_id cid = m.seg[hit - 1];
          Vertex_handle a = *m.cdt.vertices_in_constraint_begin(cid);
          Vertex_handle b = *std::prev(m.cdt.vertices_in_constraint_end(cid));
          m.seg_of.erase(cid);
          m.cdt.remove_constraint(cid);
          if (!m.cdt.are_there_incident_constraints(v)) {
            m.cdt.remove(v);
            m.vh[i] = Vertex_handle();
          }
          Constraint_id nid = m.cdt.insert_constraint(a, b);
          m.seg[hit - 1] = nid;
          m.seg_of[nid] = hit;
          again = m.vh[i] == Vertex_handle();
          continue;
        }
        if (m.cdt.are_there_incident_constraints(v)) continue;
      }
      m.cdt.remove(v);
      m.vh[i] = Vertex_handle();
      again = true;
    }
  }
}

void remove_constraint_id(Mesh& m, int sid) {
  Constraint_id cid = m.seg[sid - 1];
  m.seg_of.erase(cid);
  m.cdt.remove_constraint(cid);
  m.seg[sid - 1] = Constraint_id();
}
}

[[cpp11::register]]
int lari_remove_segments_cpp(SEXP xp, integers s0, integers s1, integers sid) {
  Mesh* m = get_mesh(xp);
  m->invalidate();
  int removed = 0;
  // by segment id
  for (R_xlen_t i = 0; i < sid.size(); ++i) {
    const int k = sid[i];
    if (k < 1 || k > (int)m->seg.size() || m->seg[k - 1] == Constraint_id()) cpp11::stop("segment %d is not in the mesh", k);
    remove_constraint_id(*m, k);
    ++removed;
  }
  // by endpoint ids, the most recently added match
  for (R_xlen_t i = 0; i < s0.size(); ++i) {
    Vertex_handle a = handle_of(*m, s0[i]), b = handle_of(*m, s1[i]);
    int found = 0;
    for (int k = (int)m->seg.size(); k >= 1 && !found; --k) {
      Constraint_id cid = m->seg[k - 1];
      if (cid == Constraint_id()) continue;
      auto vb = m->cdt.vertices_in_constraint_begin(cid);
      auto ve = m->cdt.vertices_in_constraint_end(cid);
      Vertex_handle p = *vb, q = *std::prev(ve);
      if ((p == a && q == b) || (p == b && q == a)) found = k;
    }
    if (!found) cpp11::stop("no segment between vertices %d and %d", (int)s0[i], (int)s1[i]);
    remove_constraint_id(*m, found);
    ++removed;
  }
  drop_free_crossings(*m);
  return removed;
}

[[cpp11::register]]
int lari_remove_points_cpp(SEXP xp, integers ids) {
  Mesh* m = get_mesh(xp);
  m->invalidate();
  int removed = 0;
  for (R_xlen_t i = 0; i < ids.size(); ++i) {
    const int id = ids[i];
    Vertex_handle v = handle_of(*m, id);
    // drop the input segments that end at this vertex
    for (int k = 1; k <= (int)m->seg.size(); ++k) {
      Constraint_id cid = m->seg[k - 1];
      if (cid == Constraint_id()) continue;
      Vertex_handle p = *m->cdt.vertices_in_constraint_begin(cid);
      Vertex_handle q = *std::prev(m->cdt.vertices_in_constraint_end(cid));
      if (p == v || q == v) remove_constraint_id(*m, k);
    }
    if (m->cdt.are_there_incident_constraints(v)) {
      cpp11::stop("vertex %d lies inside a constraint; remove that segment first", id);
    }
    m->cdt.remove(v);
    m->vh[id - 1] = Vertex_handle();
    ++removed;
  }
  drop_free_crossings(*m);
  return removed;
}

[[cpp11::register]]
list lari_tables_cpp(SEXP xp, int domain) {
  Mesh* m = get_mesh(xp);
  std::vector<int> row_of;
  writable::data_frame v = vertex_table(*m, row_of);
  writable::data_frame t = triangle_table(*m, row_of, domain);
  writable::data_frame s = segment_table(*m, row_of);
  return writable::list({"vertices"_nm = v, "triangles"_nm = t, "segments"_nm = s});
}

[[cpp11::register]]
list lari_counts_cpp(SEXP xp) {
  Mesh* m = get_mesh(xp);
  int by_origin[3] = {0, 0, 0};
  for (std::size_t i = 0; i < m->vh.size(); ++i) if (m->vh[i] != Vertex_handle()) ++by_origin[m->origin[i]];
  int nseg = 0;
  for (const auto& c : m->seg) if (c != Constraint_id()) ++nseg;
  const int nsub = (int)m->cdt.number_of_subconstraints();
  const Unrefined& u = m->unrefined;
  writable::integers unref({u.bad, u.short_edges, u.sharp_fixed_corner, u.circumcenter_outside, u.inserted,
                            (int)u.budget_hit});
  unref.names() = {"bad", "shortEdges", "sharpFixedCorner", "circumcenterOutside", "inserted", "budgetHit"};
  return writable::list({
    "input"_nm = by_origin[0], "crossing"_nm = by_origin[1], "steiner"_nm = by_origin[2],
    "faces"_nm = (int)m->cdt.number_of_faces(), "segments"_nm = nseg, "edges"_nm = nsub,
    "refined"_nm = (bool)u.set, "mesher_alive"_nm = (bool)(m->mesher != nullptr),
    "unrefined"_nm = unref});
}

[[cpp11::register]]
int lari_refine_cpp(SEXP xp, double min_angle, double max_area, double min_edge_length,
                    SEXP size_fun, doubles grid_x, doubles grid_y, doubles grid_z,
                    int domain, doubles seed_x, doubles seed_y, double max_steiner) {
  Mesh* m = get_mesh(xp);
  m->invalidate();
  if (m->cdt.dimension() < 2) cpp11::stop("need at least three non-collinear vertices to refine");
  Refine_settings& st = m->settings;
  st.set = true;
  st.min_angle = min_angle;
  st.max_area = max_area;
  st.min_edge_length = min_edge_length;
  st.domain = domain;
  st.seeds.clear();
  for (R_xlen_t i = 0; i < seed_x.size(); ++i) st.seeds.push_back(Point(seed_x[i], seed_y[i]));

  Lari_criteria& c = m->criteria;
  const double pi = 3.14159265358979323846;
  if (min_angle > 0) {
    const double s = std::sin(min_angle * pi / 180.0);
    c.sine2_bound = s * s;
  } else {
    c.sine2_bound = 0;
  }
  c.min_edge2 = min_edge_length > 0 ? min_edge_length * min_edge_length : 0;
  auto sz = std::make_shared<Sizing>();
  sz->max_area = max_area;
  if (grid_z.size() > 0) {
    sz->gx.assign(grid_x.begin(), grid_x.end());
    sz->gy.assign(grid_y.begin(), grid_y.end());
    sz->gz.assign(grid_z.begin(), grid_z.end());
  }
  if (size_fun != R_NilValue) { sz->has_fun = true; sz->fun = size_fun; }
  c.sizing = sz;

  const long budget = std::isfinite(max_steiner) ? (long)max_steiner : -1;
  return run_mesher(*m, budget, false);
}

[[cpp11::register]]
int lari_step_cpp(SEXP xp, int n) {
  Mesh* m = get_mesh(xp);
  if (!m->settings.set) cpp11::stop("call lari_refine() first to set the criteria");
  return run_mesher(*m, n, true);
}

[[cpp11::register]]
doubles_matrix<> lari_input_segments_cpp(SEXP xp) {
  Mesh* m = get_mesh(xp);
  int n = 0;
  for (const auto& c : m->seg) if (c != Constraint_id()) ++n;
  writable::doubles_matrix<> out(n, 4);
  int r = 0;
  for (const auto& c : m->seg) {
    if (c == Constraint_id()) continue;
    const Point& a = (*m->cdt.vertices_in_constraint_begin(c))->point();
    const Point& b = (*std::prev(m->cdt.vertices_in_constraint_end(c)))->point();
    out(r, 0) = a.x(); out(r, 1) = a.y(); out(r, 2) = b.x(); out(r, 3) = b.y();
    ++r;
  }
  return out;
}

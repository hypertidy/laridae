# laridae rebuild: plan and status

Source: the project brief "laridae: CGAL constrained meshing for the
hypertidy stack" (October 2026). Sections referenced as (s2), (s3) ...

## Sequence

1. Park the old package: preserved on branch `legacy-rcpp` (same commit as
   the old main). The old `develop` and `old-stuff` branches are untouched.
2. Build: system CGAL >= 6.0 or RcppCGAL headers, Boost or BH, cpp11, Epick
   kernel, one translation unit (s4). `configure` finds the headers.
3. Handle and contract (s2, s5): `Constrained_triangulation_plus_2` over a
   constrained Delaunay triangulation with `Exact_predicates_tag`; id -> handle
   map with tombstones; vertices / triangles / segments tables; depth.
4. Edits (s3.1): insert/remove points and constraints; crossings inserted;
   crossing vertices dropped again when the segments that made them go.
5. Refinement (s3.2): `Delaunay_mesher_2` owned by the handle, recreated after
   any edit; min angle, max area, seeds, `min_edge_length` floor (cdtr's
   default), unrefined report, `max_steiner`, `lari_step()`.
6. Sizing field (s3.3): local max area as `function(x, y)` or a grid.
7. Tests (s6): cdtr's cases ported; incremental == batch; add-then-remove
   no-op; local re-refine; step == full; sizing gradient; seeds.
8. Benchmarks (s6): `inst/benchmarks/` against cdtr and RTriangle.
9. Later / optional (s3.4): conforming Delaunay / Gabriel, 3D constrained
   triangulations, periodic triangulations; per-face-attribute sizing.

Steps 1-8 are done.

## Decisions taken while building (within the brief)

* Depth counts an edge covered by k input segments k times (CDT's
  overlap count), so coincident boundaries give nc's 1, 3, 5 when rings are
  given in full, and 1, 2, 3 when shared segments are deduplicated first,
  exactly as cdtr does on the same input.
* Triangle tables index rows of the vertex table; stable ids are the `id`
  column. Rows shift after a removal, ids never do.
* Segment table: one row per constraint edge, with the lowest covering input
  segment id and `count` of covering segments.
* Crossing attributes: the mean over the segments through the crossing of
  linear interpolation along each. Steiner attributes: barycentric in the
  triangulation as it was before the refine call.
* `size` is a local maximum area (same units as `max_area`), combined with
  `max_area` by taking the smaller.
* The floor never lets a triangle whose shortest edge is below it count as
  bad (both angle and area), matching cdtr's semantics.
* Meshing the convex hull (no constraints, or `erase = "hull"`): Mesh_2 needs
  a constrained boundary, so the hull edges are constrained for the duration
  of the refine call and released after; they never appear in the tables.
* The unrefined report counts triangles still failing a criterion, and of
  those how many are below the floor, touch a sharp constrained corner, or
  have their circumcentre outside the domain.

## Findings for the Track 2 decision (s7)

* A second refine after a small edit is local with CGAL: on nc refined at
  A/5000, q = 20, adding a short constraint and refining again inserts 6
  vertices in 3 ms against 16 ms for a full rebuild (`dynamic.R`).
* Speed: nc A/5000 q = 20 is 15 ms (laridae), 19 ms (cdtr), 5.8 ms
  (RTriangle), measured together; see inst/benchmarks/results.txt.

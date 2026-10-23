## laridae 0.1.0

First CRAN submission.

## R CMD check results

0 errors | 0 warnings | 2 notes

* This is a new submission.
* On some platforms the installed size is reported as a NOTE (about 25 Mb,
  almost all in 'libs'); see Comments.

## Comments

* 'CGAL' headers are provided by 'RcppCGAL' via LinkingTo; none are
  bundled. The package is GPL-3, matching 'CGAL'.

* The installed size is driven by 'CGAL''s header-only, heavily templated
  geometry code (constrained triangulation and the Mesh_2 refiner) compiled
  into the shared object. It is inherent to the 'CGAL' dependency and cannot
  be reduced without removing functionality.

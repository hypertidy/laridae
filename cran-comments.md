## laridae 0.1.0

First CRAN submission. 

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Comments

* 'CGAL' headers are provided by 'RcppCGAL' via LinkingTo; none are
  bundled. The package is GPL-3, matching 'CGAL'.

* Some platforms report an installed size NOTE (libs is ~25 Mb). The shared
  object is the compiled result of 'CGAL''s header-only, heavily templated
  geometry code (constrained triangulation and the Mesh_2 refiner); the size
  is inherent to the 'CGAL' dependency and cannot be reduced without removing
  functionality.

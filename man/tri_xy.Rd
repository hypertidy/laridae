% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tri_xy.R
\name{tri_xy}
\alias{tri_xy}
\alias{tri_xy1}
\alias{tri_xy2}
\title{CGAL point triangulation (unconstrained)}
\usage{
tri_xy(x, y)

tri_xy1(x, y)

tri_xy2(x, y)
}
\arguments{
\item{x}{coordinate vector}

\item{y}{coordinate vector}
}
\value{
triangle index, 1-based

triangle index, 1-based

triangle index, 1-based
}
\description{
\code{tri_xy} CGAL vertex index

This method uses a vertex iterator instead of a faces iterator.

This is the long-hand way, using an iteration over all faces, checking
whether they are finite or not, and accessing the face.vertex info by
dereferencing pointers to each vertex of the face.
}
\details{
First method uses uses a faces iterator to extract the vertex->info for
each face. A Delaunay triangulation has both finite and infinite faces
(see CGAL documentation). The infinite faces join to an external, infinite
vertex, so the finite_faces_iterator just includes the internal faces.

vertex index
}

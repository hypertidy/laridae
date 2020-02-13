#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/* FIXME: 
   Check these declarations against the C/Fortran source code.
*/

/* .C calls */
extern void insert_mesh(void *, void *, void *, void *, void *);

/* .Call calls */
extern SEXP _laridae_insert_constraint(SEXP, SEXP, SEXP, SEXP);
extern SEXP _laridae_poly_triangulation_xy(SEXP, SEXP);
extern SEXP _laridae_poly_triangulation_xylist(SEXP, SEXP, SEXP);
extern SEXP _laridae_poly_triangulation0();
extern SEXP _laridae_segment_constraint_cpp(SEXP, SEXP, SEXP);
extern SEXP _laridae_tri_xy(SEXP, SEXP);
extern SEXP _laridae_tri_xy1(SEXP, SEXP);
extern SEXP _laridae_tri_xy2(SEXP, SEXP);

static const R_CMethodDef CEntries[] = {
    {"insert_mesh", (DL_FUNC) &insert_mesh, 5},
    {NULL, NULL, 0}
};

static const R_CallMethodDef CallEntries[] = {
    {"_laridae_insert_constraint",         (DL_FUNC) &_laridae_insert_constraint,         4},
    {"_laridae_poly_triangulation_xy",     (DL_FUNC) &_laridae_poly_triangulation_xy,     2},
    {"_laridae_poly_triangulation_xylist", (DL_FUNC) &_laridae_poly_triangulation_xylist, 3},
    {"_laridae_poly_triangulation0",       (DL_FUNC) &_laridae_poly_triangulation0,       0},
    {"_laridae_segment_constraint_cpp",    (DL_FUNC) &_laridae_segment_constraint_cpp,    3},
    {"_laridae_tri_xy",                    (DL_FUNC) &_laridae_tri_xy,                    2},
    {"_laridae_tri_xy1",                   (DL_FUNC) &_laridae_tri_xy1,                   2},
    {"_laridae_tri_xy2",                   (DL_FUNC) &_laridae_tri_xy2,                   2},
    {NULL, NULL, 0}
};

void R_init_laridae(DllInfo *dll)
{
    R_registerRoutines(dll, CEntries, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

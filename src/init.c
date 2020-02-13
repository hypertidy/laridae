#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/* FIXME: 
   Check these declarations against the C/Fortran source code.
*/

/* .Call calls */
extern SEXP _laridae_insert_constraint(SEXP, SEXP, SEXP, SEXP);
extern SEXP _laridae_insert_mesh(SEXP, SEXP, SEXP, SEXP);
extern SEXP _laridae_segment_constraint_cpp(SEXP, SEXP, SEXP);
extern SEXP _laridae_tri_xy(SEXP, SEXP);
extern SEXP _laridae_tri_xy1(SEXP, SEXP);
extern SEXP _laridae_tri_xy2(SEXP, SEXP);

static const R_CallMethodDef CallEntries[] = {
    {"_laridae_insert_constraint",      (DL_FUNC) &_laridae_insert_constraint,      4},
    {"_laridae_insert_mesh",            (DL_FUNC) &_laridae_insert_mesh,            4},
    {"_laridae_segment_constraint_cpp", (DL_FUNC) &_laridae_segment_constraint_cpp, 3},
    {"_laridae_tri_xy",                 (DL_FUNC) &_laridae_tri_xy,                 2},
    {"_laridae_tri_xy1",                (DL_FUNC) &_laridae_tri_xy1,                2},
    {"_laridae_tri_xy2",                (DL_FUNC) &_laridae_tri_xy2,                2},
    {NULL, NULL, 0}
};

void R_init_laridae(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

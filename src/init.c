#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/* FIXME: 
   Check these declarations against the C/Fortran source code.
*/

/* .Call calls */
extern SEXP _cgalgris_ach();
extern SEXP _cgalgris_apoint(SEXP, SEXP);
extern SEXP _cgalgris_ctri_xy(SEXP, SEXP);
extern SEXP _cgalgris_pas();
extern SEXP _cgalgris_tri_xy(SEXP, SEXP);

static const R_CallMethodDef CallEntries[] = {
    {"_cgalgris_ach",     (DL_FUNC) &_cgalgris_ach,     0},
    {"_cgalgris_apoint",  (DL_FUNC) &_cgalgris_apoint,  2},
    {"_cgalgris_ctri_xy", (DL_FUNC) &_cgalgris_ctri_xy, 2},
    {"_cgalgris_pas",     (DL_FUNC) &_cgalgris_pas,     0},
    {"_cgalgris_tri_xy",  (DL_FUNC) &_cgalgris_tri_xy,  2},
    {NULL, NULL, 0}
};

void R_init_cgalgris(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

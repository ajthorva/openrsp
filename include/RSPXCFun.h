/*
  OpenRSP: open-ended library for response theory
  Copyright 2015 Radovan Bast,
                 Daniel H. Friese,
                 Bin Gao,
                 Dan J. Jonsson,
                 Magnus Ringholm,
                 Kenneth Ruud,
                 Andreas Thorvaldsen

  This source code form is subject to the terms of the
  GNU Lesser General Public License, version 2.1.
  If a copy of the GNU LGPL v2.1 was not distributed with this
  code, you can obtain one at https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html.


  <header name='RSPXCFun.h' author='Bin Gao' date='2014-08-06'>
    The header file of XC functionals used inside OpenRSP
  </header>
*/

#if !defined(RSP_XCFUN_H)
#define RSP_XCFUN_H

#include "qcmatrix.h"
#include "RSPPerturbation.h"

typedef void (*GetXCFunMat)(const QInt,
                            const QcPertInt*,
                            const QInt,
                            const QInt*,
                            const QInt,
                            const QInt*,
                            const QInt,
                            QcMat*[],
#if defined(OPENRSP_C_USER_CONTEXT)
                            void*,
#endif
                            const QInt,
                            QcMat*[]);
typedef void (*GetXCFunExp)(const QInt,
                            const QcPertInt*,
                            const QInt,
                            const QInt*,
                            const QInt,
                            const QInt*,
                            const QInt,
                            QcMat*[],
#if defined(OPENRSP_C_USER_CONTEXT)
                            void*,
#endif
                            const QInt,
                            QReal*);

typedef struct RSPXCFun RSPXCFun;
struct RSPXCFun {
    QInt num_pert_lab;           /* number of different perturbation labels
                                    that can act as perturbations on the
                                    XC functional */
    QInt xc_len_tuple;           /* length of perturbation tuple on the
                                    XC functional, only used for
                                    callback functions */
    QInt *pert_max_orders;       /* allowed maximal order of a perturbation
                                    described by exactly one of these
                                    different labels */
    QcPertInt *pert_labels;      /* all the different perturbation labels */
    QcPertInt *xc_pert_tuple;    /* perturbation tuple on the XC functional,
                                    only used for callback functions */
#if defined(OPENRSP_C_USER_CONTEXT)
    void *user_ctx;              /* user-defined callbac-kfunction context */
#endif
    GetXCFunMat get_xc_fun_mat;  /* user-specified function for calculating
                                    integral matrices */
    GetXCFunExp get_xc_fun_exp;  /* user-specified function for calculating
                                    expectation values */
    RSPXCFun *next_xc;           /* pointer to the next XC functional */
};

extern QErrorCode RSPXCFunCreate(RSPXCFun**,
                                 const QInt,
                                 const QcPertInt*,
                                 const QInt*,
#if defined(OPENRSP_C_USER_CONTEXT)
                                 void*,
#endif
                                 const GetXCFunMat,
                                 const GetXCFunExp);
extern QErrorCode RSPXCFunAdd(RSPXCFun*,
                              const QInt,
                              const QcPertInt*,
                              const QInt*,
#if defined(OPENRSP_C_USER_CONTEXT)
                              void*,
#endif
                              const GetXCFunMat,
                              const GetXCFunExp);
extern QErrorCode RSPXCFunAssemble(RSPXCFun*,const RSPPert*);
extern QErrorCode RSPXCFunWrite(RSPXCFun*,FILE*);
extern QErrorCode RSPXCFunGetMat(RSPXCFun*,
                                 const QInt,
                                 const QcPertInt*,
                                 const QInt,
                                 const QInt*,
                                 const QInt,
                                 const QInt*,
                                 const QInt,
                                 QcMat*[],
                                 const QInt,
                                 QcMat*[]);
extern QErrorCode RSPXCFunGetExp(RSPXCFun*,
                                 const QInt,
                                 const QcPertInt*,
                                 const QInt,
                                 const QInt*,
                                 const QInt,
                                 const QInt*,
                                 const QInt,
                                 QcMat*[],
                                 const QInt,
                                 QReal*);
extern QErrorCode RSPXCFunDestroy(RSPXCFun**);

#endif


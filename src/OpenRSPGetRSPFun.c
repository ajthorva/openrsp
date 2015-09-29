/*
  OpenRSP: open-ended library for response theory
  Copyright 2015 Radovan Bast,
                 Daniel H. Friese,
                 Bin Gao,
                 Dan J. Jonsson,
                 Magnus Ringholm,
                 Kenneth Ruud,
                 Andreas Thorvaldsen

  OpenRSP is free software: you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation, either version 3 of
  the License, or (at your option) any later version.

  OpenRSP is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OpenRSP. If not, see <http://www.gnu.org/licenses/>.

*/

#include "OpenRSP.h"

QVoid OpenRSPGetRSPFun_f(const QInt num_props,
                         const QInt *len_tuple,
                         const QInt *pert_tuple,
                         const QInt *num_freq_configs,
                         const QReal *pert_freqs,
                         const QInt *kn_rules,
                         const QcMat *ref_ham,
                         const QcMat *ref_overlap,
                         const QcMat *ref_state,
                         RSPSolver *rsp_solver,
                         RSPNucHamilton *nuc_hamilton,
                         RSPOverlap *overlap,
                         RSPOneOper *one_oper,
                         RSPTwoOper *two_oper,
                         RSPXCFun *xc_fun,
                         const QInt size_rsp_funs,
                         QReal *rsp_funs);

/*@% \brief gets the response functions for given perturbations
     \author Bin Gao
     \date 2014-07-31
     \param[OpenRSP:struct]{inout} open_rsp the context of response theory calculations
     \param[QcMat:struct]{in} ref_ham Hamiltonian of referenced state
     \param[QcMat:struct]{in} ref_state electronic state of referenced state
     \param[QcMat:struct]{in} ref_overlap overlap integral matrix of referenced state
     \param[QInt:int]{in} num_props number of properties to calculate
     \param[QInt:int]{in} len_tuple length of perturbation tuple for each property
     \param[QInt:int]{in} pert_tuple ordered list of perturbation labels
         for each property
     \param[QInt:int]{in} num_freq_configs number of different frequency
         configurations for each property
     \param[QReal:real]{in} pert_freqs complex frequencies of each perturbation label
         (except for the perturbation a) over all frequency configurations
     \param[QInt:int]{in} kn_rules number k for the kn rule for each property
     \param[QInt:int]{in} size_rsp_funs size of the response functions
     \param[QReal:real]{out} rsp_funs the response functions
     \return[QErrorCode:int] error information
*/
QErrorCode OpenRSPGetRSPFun(OpenRSP *open_rsp,
                            const QcMat *ref_ham,
                            const QcMat *ref_state,
                            const QcMat *ref_overlap,
                            const QInt num_props,
                            const QInt *len_tuple,
                            const QInt *pert_tuple,
                            const QInt *num_freq_configs,
                            const QReal *pert_freqs,
                            const QInt *kn_rules,
                            const QInt size_rsp_funs,
                            QReal *rsp_funs)
{
    //QErrorCode ierr;  /* error information */
    if (open_rsp->assembled==QFALSE) {
        QErrorExit(FILE_AND_LINE, "OpenRSPAssemble() should be invoked before any calculation");
    }
    //switch (open_rsp->elec_wav_type) {
    ///* density matrix-based response theory */
    //case ELEC_AO_D_MATRIX:
        OpenRSPGetRSPFun_f(num_props,
                           len_tuple,
                           pert_tuple,
                           num_freq_configs,
                           pert_freqs,
                           kn_rules,
                           ref_ham,
                           ref_overlap,
                           ref_state,
                           open_rsp->rsp_solver,
                           open_rsp->nuc_hamilton,
                           open_rsp->overlap,
                           open_rsp->one_oper,
                           open_rsp->two_oper,
                           open_rsp->xc_fun,
                           //id_outp,
                           size_rsp_funs,
                           rsp_funs);
    //    break;
    ///* molecular orbital (MO) coefficient matrix-based response theory */
    //case ELEC_MO_C_MATRIX:
    //    break;
    ///* couple cluster-based response theory */
    //case ELEC_COUPLED_CLUSTER:
    //    break;
    //default:
    //    printf("OpenRSPGetRSPFun>> type of (electronic) wave function %d\n",
    //           open_rsp->elec_wav_type);
    //    QErrorExit(FILE_AND_LINE, "invalid type of (electronic) wave function");
    //}
    return QSUCCESS;
}


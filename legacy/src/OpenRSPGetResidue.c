/* OpenRSP: open-ended library for response theory
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

   This file implements the function OpenRSPGetResidue().

   2015-06-29, Bin Gao:
   * first version
*/

#include "openrsp.h"

/*@% \brief gets the residues for given perturbations
     \author Bin Gao
     \date 2014-07-31
     \param[OpenRSP:struct]{inout} open_rsp the context of response theory calculations
     \param[QcMat:struct]{in} ref_ham Hamiltonian of referenced state
     \param[QcMat:struct]{in} ref_state electronic state of referenced state
     \param[QcMat:struct]{in} ref_overlap overlap integral matrix of referenced state
     \param[QInt:int]{in} order_residue order of residues, that is also the length of
         each excitation tuple
     \param[QInt:int]{in} num_excit number of excitation tuples that will be used for
         residue calculations
     \param[QReal:real]{in} excit_energy excitation energies of all tuples, size is
         ``order_residue`` :math:`\times` ``num_excit``, and arranged
         as ``[num_excit][order_residue]``; that is, there will be
         ``order_residue`` frequencies of perturbation labels (or sums
         of frequencies of perturbation labels) respectively equal to
         the ``order_residue`` excitation energies per tuple
         ``excit_energy[i][:]`` (``i`` runs from ``0`` to ``num_excit-1``)
     \param[QcMat:struct]{in} eigen_vector eigenvectors (obtained from the generalized
         eigenvalue problem) of all excitation tuples, size is ``order_residue``
         :math:`\times` ``num_excit``, and also arranged in memory
         as ``[num_excit][order_residue]`` so that each eigenvector has
         its corresponding excitation energy in ``excit_energy``
     \param[QInt:int]{in} num_props number of properties to calculate
     \param[QInt:int]{in} len_tuple length of perturbation tuple for each property
     \param[QInt:int]{in} pert_tuple ordered list of perturbation labels
         for each property
     \param[QInt:int]{in} residue_num_pert for each property and each excitation energy
         in the tuple, the number of perturbation labels whose sum of
         frequencies equals to that excitation energy, size is ``order_residue``
         :math:`\times` ``num_props``, and arragned as ``[num_props][order_residue]``;
         a negative ``residue_num_pert[i][j]`` (``i`` runs from ``0`` to
         ``num_props-1``) means that the sum of frequencies of perturbation
         labels equals to ``-excit_energy[:][j]``
     \param[QInt:int]{in} residue_idx_pert for each property and each excitation energy
         in the tuple, the indices of perturbation labels whose sum of
         frequencies equals to that excitation energy, size is
         ``sum(residue_num_pert)``, and arranged as ``[residue_num_pert]``
     \param[QInt:int]{in} num_freq_configs number of different frequency
         configurations for each property
     \param[QReal:real]{in} pert_freqs complex frequencies of each perturbation
         label (except for the perturbation a) over all frequency configurations
         and excitation tuples
     \param[QInt:int]{in} kn_rules number k for the kn rule for each property
     \param[QInt:int]{in} size_residues size of the residues
     \param[QReal:real]{out} residues the residues
     \return[QErrorCode:int] error information
*/
QErrorCode OpenRSPGetResidue(OpenRSP *open_rsp,
                             const QcMat *ref_ham,
                             const QcMat *ref_state,
                             const QcMat *ref_overlap,
                             const QInt order_residue,
                             const QInt num_excit,
                             const QReal *excit_energy,
                             QcMat *eigen_vector[],
                             const QInt num_props,
                             const QInt *len_tuple,
                             const QInt *pert_tuple,
                             const QInt *residue_num_pert,
                             const QInt *residue_idx_pert,
                             const QInt *num_freq_configs,
                             const QReal *pert_freqs,
                             const QInt *kn_rules,
                             const QInt size_residues,
                             QReal *residues)
{
    //QErrorCode ierr;  /* error information */
    if (open_rsp->assembled==QFALSE) {
        QErrorExit(FILE_AND_LINE, "OpenRSPAssemble() should be invoked before any calculation");
    }
    switch (open_rsp->elec_wav_type) {
    /* density matrix-based response theory */
    case ELEC_AO_D_MATRIX:
        break;
    /* molecular orbital (MO) coefficient matrix-based response theory */
    case ELEC_MO_C_MATRIX:
        break;
    /* couple cluster-based response theory */
    case ELEC_COUPLED_CLUSTER:
        break;
    default:
        printf("OpenRSPGetResidue>> type of (electronic) wave function %d\n",
               open_rsp->elec_wav_type);
        QErrorExit(FILE_AND_LINE, "invalid type of (electronic) wave function");
    }
    return QSUCCESS;
}

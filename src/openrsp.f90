!!  openrsp: interface for solving response equations using atomic basis
!!  Copyright 2009 Bin Gao
!!
!!  This file is part of openrsp.
!!
!!  openrsp is free software: you can redistribute it and/or modify
!!  it under the terms of the GNU Lesser General Public License as published by
!!  the Free Software Foundation, either version 3 of the License, or
!!  (at your option) any later version.
!!
!!  openrsp is distributed in the hope that it will be useful,
!!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
!!  GNU Lesser General Public License for more details.
!!
!!  You should have received a copy of the GNU Lesser General Public License
!!  along with openrsp. If not, see <http://www.gnu.org/licenses/>.
!!
!!  openrsp is an interface for solving response equations using
!!  Andreas J. Thorvaldsen's codes, and the solver in DALTON
!!
!!  NOTICE: DALTON is distributed under its own License Agreement
!!          You need to first obtain such agreement and DALTON
!!          from http://www.kjemi.uio.no/software/dalton/dalton.html
!!
!!  NOTICE: Andreas J. Thorvaldsen's codes are also distributed under
!!          GNU Lesser General Public License, you may also first
!!          obtain his code
!!
!!  This file is the main module of openrsp, provides external user interfaces,
!!  also contains the interface of calling Andreas J. Thorvaldsen's codes
!!
!!  2009-12-08, Bin Gao:
!!  * first version

!> \brief main module of openrsp
!> \details contains the external user interfaces,
!>          and the interface of calling Andreas J. Thorvaldsen's codes
!> \author Bin Gao
!> \date 2009-12-08
module openrsp

  use interface_molecule
  use interface_io
  use interface_xc
  use interface_pcm
  use interface_scf
  use interface_f77_memory
  use interface_rsp_solver
  use interface_1el
  use interface_basis
  use interface_dirac_gen1int
  use interface_interest
  use rsp_field_tuple, only: p_tuple, p_tuple_standardorder
  use rsp_general, only: rsp_prop
  use dalton_ifc
  use openrsp_cfg
  use matrix_defop
  use matrix_lowlevel,  only: mat_init
  use eri_contractions, only: ctr_arg
  use eri_basis_loops,  only: unopt_geodiff_loop
  use legacy_vibrational_properties, only: load_vib_modes
  use vib_pv_contribs
  use rsp_sdf_caching
  use rsp_mag_prop

! xcint
  use interface_ao_specific
  use xcint_integrator

  implicit none

  public openrsp_setup
  public openrsp_calc
  public openrsp_finalize

  private

  ! ------------- SCF state and settings ------------
  ! overlap matrix
  type(matrix) S
  ! AO density matrix
  type(matrix), target :: D
  ! Fock matrix
  type(matrix) F

  ! --------------- geometry and basis settings -----------
  ! number of atoms
  integer num_atoms
  ! number of cgto shell blocks
  integer num_cgto_blocks
  ! number of exponents and contraction coefficients
  integer num_exp_and_ctr
  ! array to hold exponents and contraction coefs
  real(8), allocatable :: exp_and_ctr(:)

  ! print level to be used here and in solver
  integer :: print_level = 0

contains

  subroutine openrsp_setup(WAVPCM, LWORK, WORK)
    logical, intent(in)    :: WAVPCM
    integer, intent(in)    :: LWORK
    integer                :: nbast, lupri
    real(8), intent(inout) :: WORK(LWORK)
    type(matrix)           :: H1 !one electron Hamiltonian
    type(matrix)           :: G  !two electron Hamiltonian
    real(8), allocatable   :: xc_dmat(:)
    real(8), allocatable   :: xc_fmat(:)
    integer                :: mat_dim
    real(8)                :: xc_energy
    real(8), target        :: temp(1)
    real(8)                :: ave(100)

    type(ctr_arg) :: arg(1)

    call interface_molecule_init()
    call interface_io_init()
    call interface_xc_init()
    call interface_pcm_init(wavpcm)
    call interface_scf_init()
    call interface_basis_init()

    nbast = get_nr_ao()
    lupri = get_print_unit()

    ! prints the header and license information
    call TITLER('OpenRSP: Response functions computed using AO basis', '*', -1)
    write (LUPRI,*) '>> -- solving equations with the MO response solver in DALTON.'
    write (LUPRI,*)
    write (LUPRI,*) '>> Original reference:'
    write (LUPRI,*) '>>  Andreas J. Thorvaldsen, Kenneth Ruud, Kasper Kristensen,'// &
                        ' Poul Jorgensen, and Sonia Coriani, '
    write (LUPRI,*) '>>  J. Chem. Phys. 129, 214108 (2008).'
    write (LUPRI,*)

    call interface_f77_memory_init(work_len=lwork, work=work)

    ! initialize the MO response solver
    call rsp_mosolver_init(openrsp_cfg_solver_maxitr, &
                           openrsp_cfg_solver_maxphp, &
                           openrsp_cfg_solver_maxred, &
                           openrsp_cfg_solver_thresh, &
                           openrsp_cfg_solver_optorb)

    ! initialize and allocate overlap matrix
    call mat_init(S, NBAST, NBAST)

    ! get the overlap
    call interface_scf_get_s(S)

    ! get the AO density matrix and divide by 2
    D = 0*S
    call mat_ensure_alloc(D, only_alloc=.true.)
    call interface_scf_get_d(D)
    D = 0.5d0*D

    ! get the one electron Hamiltonian
    H1 = 0*S
    call mat_ensure_alloc(H1, only_alloc=.true.)
    call interface_scf_get_h1(H1)

    ! get the two electron contribution (G) to Fock matrix
    G = 0*S
    call mat_ensure_alloc(G, only_alloc=.true.)
    call interface_scf_get_g(D, G)

    ! Fock matrix F = H1 + G
    F = H1 + G

    H1 = 0
    G  = 0

    if (get_is_ks_calculation()) then
       ! write xcint interface files
       call interface_ao_write()

       ! add xc contribution to the fock matrix
       mat_dim = D%nrow
       allocate(xc_dmat(mat_dim*mat_dim))
       xc_dmat = 0.0d0
       call daxpy(mat_dim*mat_dim, 1.0d0, D%elms, 1, xc_dmat, 1)
       allocate(xc_fmat(mat_dim*mat_dim))
       call xc_integrate(                  &
                         mat_dim=mat_dim,  &
                         nr_dmat=1,        &
                         dmat=xc_dmat,     &
                         energy=xc_energy, &
                         get_ave=.false.,  &
                         fmat=xc_fmat,     &
                         geo_coor=(/0/),   &
                         pert_labels=(/'NONE'/), &
                         kn=(/0, 0/)       &
                        )
       call daxpy(mat_dim*mat_dim, 1.0d0, xc_fmat, 1, F%elms, 1)
       deallocate(xc_dmat)
       deallocate(xc_fmat)
    end if

    num_atoms = get_nr_atoms()

end subroutine

  subroutine openrsp_calc()

    integer       :: kn(2)
    integer       :: i, setup_i
    type(p_tuple) :: perturbation_tuple
    type(matrix) :: zeromat_already
    type(SDF), pointer :: F_already, D_already, S_already
    real(8), dimension(3) :: fld_dum
    real(8), dimension(3) :: dm
    character(len=4) :: file_id
    character(20) :: format_line
    integer       :: n_nm, h, j, k, m, ierr
    real(8), allocatable, dimension(:) :: nm_freq, nm_freq_b
    real(8), allocatable, dimension(:) :: hr_intensities_hv, hr_intensities_vv
    real(8), allocatable, dimension(:,:) :: T
    real(8), dimension(3,3) :: ff
    real(8), dimension(3,3,3) :: fff
    real(8) :: c0, reccm
    complex(8), dimension(3) :: CID
    complex(8), allocatable, dimension(:,:) :: egf_cart, egf_nm, ff_pv
    complex(8), allocatable, dimension(:,:,:) :: egff_cart, egff_nm, fff_pv
    complex(8), allocatable, dimension(:,:,:,:) :: egfff_cart, egfff_nm, ffff_pv
    complex(8), dimension(3,3,3,3) :: Effff, Effmfww, Effmfw2w
    complex(8), dimension(3,3,6,3) :: Effqfww, Effqfw2w


    if (openrsp_cfg_general_specify) then

       kn = openrsp_cfg_specify_kn

       perturbation_tuple%n_perturbations = openrsp_cfg_specify_order
       allocate(perturbation_tuple%pdim(perturbation_tuple%n_perturbations))
       allocate(perturbation_tuple%plab(perturbation_tuple%n_perturbations))
       allocate(perturbation_tuple%pid(perturbation_tuple%n_perturbations))
       allocate(perturbation_tuple%freq(perturbation_tuple%n_perturbations))

       perturbation_tuple%plab = openrsp_cfg_specify_plab

       do i = 1, openrsp_cfg_specify_order

          if (openrsp_cfg_specify_plab(i) == 'GEO ') then

             perturbation_tuple%pdim(i) = 3*num_atoms

          elseif (openrsp_cfg_specify_plab(i) == 'EL  ') then

             perturbation_tuple%pdim(i) = 3

          elseif (openrsp_cfg_specify_plab(i) == 'MAG ') then

             perturbation_tuple%pdim(i) = 3

          else

             write(*,*) 'ERROR: Unrecognized field', openrsp_cfg_specify_plab(i)
             write(*,*) 'encountered when setting up customized response property calculation'

          end if

       end do
       
       perturbation_tuple%pid = (/(i, i = 1, openrsp_cfg_specify_order)/)

       ! Requires that openrsp_cfg_nr_freq_tuples is set to 1 if no frequencies specified
       ! That is currently the default
       ! Requires that openrsp_cfg_nr_real_freqs is used as freqs. per tuple
       ! That is also currently the default

       do k = 1, openrsp_cfg_nr_freq_tuples

          if(allocated(openrsp_cfg_real_freqs)) then

             perturbation_tuple%freq = (/(i * 0.0d0 , i = 1, openrsp_cfg_specify_order - &
             openrsp_cfg_nr_real_freqs - 1), (-1.0) * &
             sum(openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1: &
                                              k * openrsp_cfg_nr_real_freqs)), &
                 openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1: &
                                              k * openrsp_cfg_nr_real_freqs) /)

          else

             perturbation_tuple%freq = (/(i * 0.0d0 , i = 1, openrsp_cfg_specify_order)/)

          end if

          perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
          perturbation_tuple%pid = (/(i, i = 1, openrsp_cfg_specify_order)/)

file_id = '    '


          write(file_id, '(I4)') k


          if (openrsp_cfg_nr_freq_tuples == 1) then

             call rsp_prop(perturbation_tuple, kn, F_unpert=F, D_unpert=D, S_unpert=S)

          else

             if (k == 1) then

                ! ASSUME CLOSED SHELL
                call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
                call mat_init_like_and_zero(S, zeromat_already)


                call sdf_setup_datatype(S_already, S)
                call sdf_setup_datatype(D_already, D)
                call sdf_setup_datatype(F_already, F)

             end if

             call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, &
                           file_id = 'freq_tuple_' // trim(adjustl(file_id)))

          end if

       end do


    end if


    if (openrsp_cfg_general_shg) then


       ! Calculate dipole moment

       kn = (/0,0/)

       perturbation_tuple%n_perturbations = 1
       allocate(perturbation_tuple%pdim(1))
       allocate(perturbation_tuple%plab(1))
       allocate(perturbation_tuple%pid(1))
       allocate(perturbation_tuple%freq(1))

       perturbation_tuple%plab = (/'EL  '/)
       perturbation_tuple%pdim = (/3/)
       perturbation_tuple%pid = (/1/)
       perturbation_tuple%freq = (/0.0d0/)

       call rsp_prop(perturbation_tuple, kn, F_unpert=F, D_unpert=D, S_unpert=S, file_id='Ef')

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

       ! Read dipole moment from file

       open(unit = 258, file='rsp_tensor_Ef', status='old', action='read', iostat=ierr)
       read(258,*) fld_dum
          dm = fld_dum
       close(258)

       ! Normalize dipole moment - follows procedure by AJT

       if ( ((sum(dm * dm))**0.5) < 0.00001 ) then

          dm = (/0d0, 0d0, 1d0/)

       else

          dm = dm/((sum(dm * dm))**0.5)

       end if



       ! Requires that openrsp_cfg_nr_freq_tuples is set to 1 if no frequencies specified
       ! That is currently the default
       ! Requires that openrsp_cfg_nr_real_freqs is used as freqs. per tuple
       ! That is also currently the default

          open(unit = 320, file='shg_output', status='replace', action='write', iostat=ierr)
write(320, *) 'Second harmonic generation output'
write(320, *) '================================='
write(320, *) ' '


       do k = 1, openrsp_cfg_nr_freq_tuples

          write(320,*) 'Frequency combination', k
          write(320,*) ' '

          if (k == 1) then

             ! ASSUME CLOSED SHELL
             call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
             call mat_init_like_and_zero(S, zeromat_already)

             call sdf_setup_datatype(S_already, S)
             call sdf_setup_datatype(D_already, D)
             call sdf_setup_datatype(F_already, F)

          end if


! alpha(-2w; 2w)


          kn = (/0,1/)

          perturbation_tuple%n_perturbations = 2
          allocate(perturbation_tuple%pdim(2))
          allocate(perturbation_tuple%plab(2))
          allocate(perturbation_tuple%pid(2))
          allocate(perturbation_tuple%freq(2))

          perturbation_tuple%plab = (/'EL  ',  'EL  '/)
          perturbation_tuple%pdim = (/3, 3/)
          perturbation_tuple%pid = (/1, 2/)

          if(allocated(openrsp_cfg_real_freqs)) then

             perturbation_tuple%freq = (/ (-1.0) * &
             sum(openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1: &
                                              k * openrsp_cfg_nr_real_freqs)), &
             sum(openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1: &
                                              k * openrsp_cfg_nr_real_freqs))/)

          else

             perturbation_tuple%freq = (/(i * 0.0d0 , i = 1, openrsp_cfg_specify_order)/)

          end if

          perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
          perturbation_tuple%pid = (/1, 2/)

          write(file_id, '(I4)'), k


          call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                        S_already=S_already, zeromat_already=zeromat_already, &
                        file_id = 'ff2w_freq_tuple_' // trim(adjustl(file_id)))


          open(unit = 258, file='rsp_tensor_' // 'ff2w_freq_tuple_' // trim(adjustl(file_id)), &
               status='old', action='read', iostat=ierr)


          write(320,*) ' '
          write(320,*) 'Polarizability (-2w;2w)'
          write(320,*) '======================='
          write(320,*) ' '
          write(320,*) 'Frequencies w0, w1 are', perturbation_tuple%freq(1), ' ,', &
                        perturbation_tuple%freq(2)
          write(320,*) ' '
          write(320,*) 'Polarizability:'
          write(320,*) ' '


          ff = 0.0

          format_line = '(      f20.8)'
          write(format_line(2:7), '(i6)') size(ff,1)

          do i = 1, 3
                read(258,*) fld_dum
                ff(i, :) = fld_dum
                write(320, format_line) ff(i,:)
          end do


          write(320,*) ' '
          write(320,*) 'Isotropic:', real(((1.0)/(3.0)) * &
                                     (ff(1,1) + ff(2,2) + ff(3,3)))
          ! Follows method by AJT
          write(320,*) 'Dipole^2', real(sum( (/ ((ff(i,j) * dm(i) * dm(j), &
                                   i = 1, 3), j = 1, 3) /) ))
          write(320,*) ' '



          close(258)

          deallocate(perturbation_tuple%pdim)
          deallocate(perturbation_tuple%plab)
          deallocate(perturbation_tuple%pid)
          deallocate(perturbation_tuple%freq)

! alpha(-w; w)


          kn = (/0,1/)

          perturbation_tuple%n_perturbations = 2
          allocate(perturbation_tuple%pdim(2))
          allocate(perturbation_tuple%plab(2))
          allocate(perturbation_tuple%pid(2))
          allocate(perturbation_tuple%freq(2))

          perturbation_tuple%plab = (/'EL  ',  'EL  '/)
          perturbation_tuple%pdim = (/3, 3/)
          perturbation_tuple%pid = (/1, 2/)

          if(allocated(openrsp_cfg_real_freqs)) then

             perturbation_tuple%freq = (/ (-1.0) * &
             openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1), &
             openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1)/)

          else

             perturbation_tuple%freq = (/(i * 0.0d0 , i = 1, openrsp_cfg_specify_order)/)

          end if

          perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
          perturbation_tuple%pid = (/1, 2/)

          write(file_id, '(I4)'), k


          call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                        S_already=S_already, zeromat_already=zeromat_already, &
                        file_id = 'ffw_freq_tuple_' // trim(adjustl(file_id)))


          open(unit = 258, file='rsp_tensor_' // 'ffw_freq_tuple_' // trim(adjustl(file_id)), &
               status='old', action='read', iostat=ierr)


          write(320,*) ' '
          write(320,*) 'Polarizability (-w;w)'
          write(320,*) '======================='
          write(320,*) ' '
          write(320,*) 'Frequencies w0, w1 are', perturbation_tuple%freq(1), ' ,', &
                        perturbation_tuple%freq(2)
          write(320,*) ' '
          write(320,*) 'Polarizability:'
          write(320,*) ' '


          ff = 0.0

          format_line = '(      f20.8)'
          write(format_line(2:7), '(i6)') size(ff,1)

          do i = 1, 3
                read(258,*) fld_dum
                ff(i, :) = fld_dum
                write(320, format_line) ff(i,:)
          end do


          write(320,*) ' '
          write(320,*) 'Isotropic:', real(((1.0)/(3.0)) * &
                                     (ff(1,1) + ff(2,2) + ff(3,3)))
          ! Follows method by AJT
          write(320,*) 'Dipole^2', real(sum( (/ ((ff(i,j) * dm(i) * dm(j), &
                                   i = 1, 3), j = 1, 3) /) ))
          write(320,*) ' '



          close(258)

          deallocate(perturbation_tuple%pdim)
          deallocate(perturbation_tuple%plab)
          deallocate(perturbation_tuple%pid)
          deallocate(perturbation_tuple%freq)


! beta(-w; w)


          kn = (/1,1/)

          perturbation_tuple%n_perturbations = 3
          allocate(perturbation_tuple%pdim(3))
          allocate(perturbation_tuple%plab(3))
          allocate(perturbation_tuple%pid(3))
          allocate(perturbation_tuple%freq(3))

          perturbation_tuple%plab = (/'EL  ', 'EL  ', 'EL  '/)
          perturbation_tuple%pdim = (/3, 3, 3/)
          perturbation_tuple%pid = (/1, 2, 3/)



          if(allocated(openrsp_cfg_real_freqs)) then

             perturbation_tuple%freq = (/(i * 0.0d0 , i = 1, openrsp_cfg_specify_order - &
             openrsp_cfg_nr_real_freqs - 1), (-1.0) * &
             sum(openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1: &
                                              k * openrsp_cfg_nr_real_freqs)), &
                 openrsp_cfg_real_freqs((k - 1) * openrsp_cfg_nr_real_freqs + 1: &
                                              k * openrsp_cfg_nr_real_freqs) /)

          else

             perturbation_tuple%freq = (/(i * 0.0d0 , i = 1, openrsp_cfg_specify_order)/)

          end if

          perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
          perturbation_tuple%pid = (/1, 2, 3/)

          write(file_id, '(I4)'), k


          call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                        S_already=S_already, zeromat_already=zeromat_already, &
                        file_id = 'fff_freq_tuple_' // trim(adjustl(file_id)))



          write(320,*) ' '
          write(320,*) 'Hyperpolarizability (-2w;w,w)'
          write(320,*) '============================='
          write(320,*) ' '
          write(320,*) 'Frequencies w0, w1, w2 are', perturbation_tuple%freq(1), ' ,', &
                        perturbation_tuple%freq(2), perturbation_tuple%freq(3)
          write(320,*) ' '
          write(320,*) 'Hyperpolarizability:'
          write(320,*) ' '

          open(unit = 258, file='rsp_tensor_' // 'fff_freq_tuple_' // trim(adjustl(file_id)), &
               status='old', action='read', iostat=ierr)

          fff = 0.0

          format_line = '(      f20.8)'
          write(format_line(2:7), '(i6)') size(ff,1)

          do i = 1, 3
             do j = 1, 3
                read(258,*) fld_dum
                fff(i, j, :) = fld_dum
                write(320, format_line) fff(i,j,:)
             end do
          end do

          close(258)

          write(320,*) ' '
          ! Follows method by AJT
          write(320,*) 'Isotropic:', real((1.0/5.0) * sum ( (/ (( (fff(i,i,j) + &
                       fff(i,j,i) + fff(j,i,i)) * dm(j), i = 1, 3), j = 1, 3) /)))
          ! Follows method by AJT
          write(320,*) 'Dipole^3', real(sum( (/ (((fff(i,j,k) * dm(i) * dm(j) * dm(k), &
                                   i = 1, 3), j = 1, 3), k = 1, 3) /) ))
          write(320,*) ' '




          deallocate(perturbation_tuple%pdim)
          deallocate(perturbation_tuple%plab)
          deallocate(perturbation_tuple%pid)
          deallocate(perturbation_tuple%freq)


       end do

       close(320)

    end if



    if (openrsp_cfg_general_pv2f) then

       ! Calculate dipole moment

       kn = (/0,0/)

       perturbation_tuple%n_perturbations = 1
       allocate(perturbation_tuple%pdim(1))
       allocate(perturbation_tuple%plab(1))
       allocate(perturbation_tuple%pid(1))
       allocate(perturbation_tuple%freq(1))

       perturbation_tuple%plab = (/'EL  '/)
       perturbation_tuple%pdim = (/3/)
       perturbation_tuple%pid = (/1/)
       perturbation_tuple%freq = (/0.0d0/)

       call rsp_prop(perturbation_tuple, kn, F, D, S, file_id='Ef')

       ! Read dipole moment from file

       open(unit = 258, file='rsp_tensor_Ef', status='old', action='read', iostat=ierr)
       read(258,*) fld_dum
          dm = fld_dum
       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

       ! Get normal mode transformation matrix
       ! Get normal mode frequencies

       fld_dum = 0.0

       allocate(T(3*num_atoms, 3*num_atoms))
       allocate(nm_freq_b(3*num_atoms))

       nm_freq_b = 0.0

       call load_vib_modes(3*num_atoms, n_nm, nm_freq_b, T)

       allocate(nm_freq(n_nm))

       nm_freq = 0.0

       nm_freq = nm_freq_b(1:n_nm)
       deallocate(nm_freq_b)

       allocate(ff_pv(3, 3))
       allocate(egf_cart(3*num_atoms, 3))
       allocate(egf_nm(n_nm, 3))

       ff_pv = 0.0
       egf_cart = 0.0
       egf_nm = 0.0

       ! Calculate gradient of dipole moment

       kn = (/0,1/)

       perturbation_tuple%n_perturbations = 2
       allocate(perturbation_tuple%pdim(2))
       allocate(perturbation_tuple%plab(2))
       allocate(perturbation_tuple%pid(2))
       allocate(perturbation_tuple%freq(2))

       perturbation_tuple%plab = (/'GEO ', 'EL  '/)
       perturbation_tuple%pdim = (/3*num_atoms, 3/)
       perturbation_tuple%pid = (/1, 2/)
       perturbation_tuple%freq = (/0.0d0, 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2/)


       ! ASSUME CLOSED SHELL
       call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
       call mat_init_like_and_zero(S, zeromat_already)


       call sdf_setup_datatype(S_already, S)
       call sdf_setup_datatype(D_already, D)
       call sdf_setup_datatype(F_already, F)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Egf')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Egf', status='old', action='read', iostat=ierr)

       do i = 1, 3*num_atoms
          read(258,*) fld_dum
          egf_cart(i, :) = fld_dum
       end do

       close(258)

       egf_nm = trans_cartnc_1w1d(3*num_atoms, n_nm, egf_cart, T(:,1:n_nm))


       ! Normalize dipole moment - follows procedure by AJT

       if ( ((sum(dm * dm))**0.5) < 0.00001 ) then

          dm = (/0d0, 0d0, 1d0/)

       else

          dm = dm/((sum(dm * dm))**0.5)

       end if

       do k = 1, openrsp_cfg_nr_freq_tuples

          ! Calculate PV contribution to polarizability

          ff_pv = alpha_pv(n_nm, nm_freq, (/ (-1.0)* openrsp_cfg_real_freqs(k), &
                           openrsp_cfg_real_freqs(k) /), dm_1d = egf_nm)

          if (k == 1) then

             open(unit=259, file='alpha_pv', status='replace', action='write') 

          else

             open(unit=259, file='alpha_pv', status='old', action='write', position='append') 

          end if

          write(259,*) 'Pure vibrational output'
          write(259,*) '======================='
          write(259,*) ' '
          write(259,*) 'Frequency combination', k
          write(259,*) ' '
          write(259,*) 'Frequencies w0, w1 are', (-1.0)* openrsp_cfg_real_freqs(k), ' ,', &
                     openrsp_cfg_real_freqs(k)
          write(259,*) ' '
          write(259,*) 'PV contribution to polarizability'
          write(259,*) '================================='
          write(259,*) ' '

          format_line = '(      f20.8)'
          write(format_line(2:7), '(i6)') size(ff_pv,1)
          

          do i = 1, 3
             write(259, format_line) real(ff_pv(i,:))
          end do
          write(259,*) ' '
          write(259,*) 'Isotropic:', real(((1.0)/(3.0)) * (ff_pv(1,1) + ff_pv(2,2) + ff_pv(3,3)))
          ! Follows method by AJT
          write(259,*) 'Dipole^2', real(sum( (/ ((ff_pv(i,j) * dm(i) * dm(j), &
                                   i = 1, 3), j = 1, 3) /) ))
          write(259,*) ' '

          close(259)

       end do

       deallocate(T)
       deallocate(ff_pv)
       deallocate(egf_cart)
       deallocate(egf_nm)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

    end if

    if (openrsp_cfg_general_pv3f) then

       ! Calculate dipole moment

       kn = (/0,0/)

       perturbation_tuple%n_perturbations = 1
       allocate(perturbation_tuple%pdim(1))
       allocate(perturbation_tuple%plab(1))
       allocate(perturbation_tuple%pid(1))
       allocate(perturbation_tuple%freq(1))

       perturbation_tuple%plab = (/'EL  '/)
       perturbation_tuple%pdim = (/3/)
       perturbation_tuple%pid = (/1/)
       perturbation_tuple%freq = (/0.0d0/)

       call rsp_prop(perturbation_tuple, kn, F, D, S, file_id='Ef')

       ! Read dipole moment from file

       open(unit = 258, file='rsp_tensor_Ef', status='old', action='read', iostat=ierr)
       read(258,*) fld_dum
          dm = fld_dum
       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

       fld_dum = 0.0

       ! Get normal mode transformation matrix
       ! Get normal mode frequencies

       allocate(T(3*num_atoms, 3*num_atoms))

       allocate(nm_freq_b(3*num_atoms))

       nm_freq_b = 0.0

       call load_vib_modes(3*num_atoms, n_nm, nm_freq_b, T)

       allocate(nm_freq(n_nm))

       nm_freq = 0.0

       nm_freq = nm_freq_b(1:n_nm)
       deallocate(nm_freq_b)

       allocate(ff_pv(3, 3))
       allocate(fff_pv(3, 3, 3))
       allocate(egf_cart(3*num_atoms, 3))
       allocate(egf_nm(n_nm, 3))
       allocate(egff_cart(3*num_atoms, 3, 3))
       allocate(egff_nm(n_nm, 3, 3))

       ff_pv = 0.0
       fff_pv = 0.0
       egf_cart = 0.0
       egf_nm = 0.0
       egff_cart = 0.0
       egff_nm = 0.0

       ! Calculate gradient of dipole moment

       kn = (/0,1/)

       perturbation_tuple%n_perturbations = 2
       allocate(perturbation_tuple%pdim(2))
       allocate(perturbation_tuple%plab(2))
       allocate(perturbation_tuple%pid(2))
       allocate(perturbation_tuple%freq(2))

       perturbation_tuple%plab = (/'GEO ', 'EL  '/)
       perturbation_tuple%pdim = (/3*num_atoms, 3/)
       perturbation_tuple%pid = (/1, 2/)
       perturbation_tuple%freq = (/0.0d0, 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2/)

       ! ASSUME CLOSED SHELL
       call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
       call mat_init_like_and_zero(S, zeromat_already)


       call sdf_setup_datatype(S_already, S)
       call sdf_setup_datatype(D_already, D)
       call sdf_setup_datatype(F_already, F)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Egf')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Egf', status='old', action='read', iostat=ierr)

       do i = 1, 3*num_atoms
          read(258,*) fld_dum
          egf_cart(i, :) = fld_dum
       end do

       close(258)

       egf_nm = trans_cartnc_1w1d(3*num_atoms, n_nm, egf_cart, T(:,1:n_nm))


       ! Normalize dipole moment - follows procedure by AJT

       if ( ((sum(dm * dm))**0.5) < 0.00001 ) then

          dm = (/0d0, 0d0, 1d0/)

       else

          dm = dm/((sum(dm * dm))**0.5)

       end if


       do k = 1, openrsp_cfg_nr_freq_tuples

          do h = 1, 2

             ! Calculate PV contribution to polarizability

             ff_pv = alpha_pv(n_nm, nm_freq, (/ (-1.0) * &
                              openrsp_cfg_real_freqs((k - 1) * 2 + h), &
                              openrsp_cfg_real_freqs((k - 1) * 2 + h) /), dm_1d = egf_nm) 


             if (k * h == 1) then

                open(unit=259, file='alpha_pv', status='replace', action='write') 

             else

                open(unit=259, file='alpha_pv', status='old', action='write', position='append') 

             end if

             write(259,*) 'Pure vibrational output'
             write(259,*) '======================='
             write(259,*) ' '
             write(259,*) 'Frequency combination', (k - 1) * 2 + h
             write(259,*) ' '
             write(259,*) 'Frequencies w0, w1 are', (-1.0)* &
                          openrsp_cfg_real_freqs((k - 1) * 2 + h), ' ,', &
                          openrsp_cfg_real_freqs((k - 1) * 2 + h)
             write(259,*) ' '
             write(259,*) 'PV contribution to polarizability'
             write(259,*) '================================='
             write(259,*) ' '
             format_line = '(      f20.8)'
             write(format_line(2:7), '(i6)') size(ff_pv,1)
          
             do i = 1, 3
                write(259, format_line) real(ff_pv(i,:))
             end do
             write(259,*) ' '
             write(259,*) 'Isotropic:', real(((1.0)/(3.0)) * &
                                        (ff_pv(1,1) + ff_pv(2,2) + ff_pv(3,3)))
             ! Follows method by AJT
             write(259,*) 'Dipole^2', real(sum( (/ ((ff_pv(i,j) * dm(i) * dm(j), &
                                      i = 1, 3), j = 1, 3) /) ))
             write(259,*) ' '

             close(259)

          end do

       end do

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

      ! Calculate gradient of polarizability

       kn = (/0,2/)

       perturbation_tuple%n_perturbations = 3
       allocate(perturbation_tuple%pdim(3))
       allocate(perturbation_tuple%plab(3))
       allocate(perturbation_tuple%pid(3))
       allocate(perturbation_tuple%freq(3))

       perturbation_tuple%plab = (/'GEO ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/3*num_atoms, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3/)
       perturbation_tuple%freq = (/0.0d0, 0.0d0, 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3/)

       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Egff')

       ! Read polarizability gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Egff', status='old', action='read', iostat=ierr)

       do i = 1, 3*num_atoms
          do j = 1, 3
             read(258,*) fld_dum
             egff_cart(i, j, :) = fld_dum
          end do
       end do

       close(258)

       egff_nm = trans_cartnc_2w1d(3*num_atoms, n_nm, egff_cart, T(:,1:n_nm))

       do k = 1, openrsp_cfg_nr_freq_tuples

          ! Calculate PV contribution to 1st hyperpolarizability

          fff_pv = beta_pv(n_nm, nm_freq, (/ (-1.0) * &
                   sum(openrsp_cfg_real_freqs((k-1)*2 + 1: (k-1)*2 + 2)), &
                   openrsp_cfg_real_freqs((k-1)*2 + 1), &
                   openrsp_cfg_real_freqs((k-1)*2 + 2) /), dm_1d = egf_nm, po_1d = egff_nm)

          if (k == 1) then

             open(unit=259, file='beta_pv', status='replace', action='write') 

          else

             open(unit=259, file='beta_pv', status='old', action='write', position='append') 

          end if

          write(259,*) 'Pure vibrational output'
          write(259,*) '======================='
          write(259,*) ' '
          write(259,*) 'Frequency combination', k
          write(259,*) ' '
          write(259,*) 'Frequencies w0, w1, w2 are', (-1.0) * &
                       sum(openrsp_cfg_real_freqs((k-1)*2 + 1: (k-1)*2 + 2)), ' ,', &
                       openrsp_cfg_real_freqs((k-1)*2 + 1), ' ,', &
                       openrsp_cfg_real_freqs((k-1)*2 + 2)
          write(259,*) ' '
          write(259,*) 'PV contribution to 1st hyperpolarizability'
          write(259,*) '=========================================='
          write(259,*) ' '

          format_line = '(      f20.8)'
          write(format_line(2:7), '(i6)') size(ff_pv,1)

          do i = 1, 3
             do j = 1, 3
                write(259, format_line) real(fff_pv(i,j,:))
             end do
             write(259,*) ' '
          end do
          ! Follows method by AJT
          write(259,*) 'Isotropic:', real((1.0/5.0) * sum ( (/ (( (fff_pv(i,i,j) + &
                       fff_pv(i,j,i) + fff_pv(j,i,i)) * dm(j), i = 1, 3), j = 1, 3) /)))
          ! Follows method by AJT
          write(259,*) 'Dipole^3', real(sum( (/ (((fff_pv(i,j,k) * dm(i) * dm(j) * dm(k), &
                                   i = 1, 3), j = 1, 3), k = 1, 3) /) ))
          write(259,*) ' '

          close(259)

       end do

       deallocate(T)
       deallocate(nm_freq)
       deallocate(ff_pv)
       deallocate(fff_pv)
       deallocate(egf_cart)
       deallocate(egf_nm)
       deallocate(egff_cart)
       deallocate(egff_nm)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

    end if

    if (openrsp_cfg_general_pv4f) then

       ! Calculate dipole moment

       kn = (/0,0/)

       perturbation_tuple%n_perturbations = 1
       allocate(perturbation_tuple%pdim(1))
       allocate(perturbation_tuple%plab(1))
       allocate(perturbation_tuple%pid(1))
       allocate(perturbation_tuple%freq(1))

       perturbation_tuple%plab = (/'EL  '/)
       perturbation_tuple%pdim = (/3/)
       perturbation_tuple%pid = (/1/)
       perturbation_tuple%freq = (/0.0d0/)

       call rsp_prop(perturbation_tuple, kn, F, D, S, file_id='Ef')

       ! Read dipole moment from file

       open(unit = 258, file='rsp_tensor_Ef', status='old', action='read', iostat=ierr)
       read(258,*) fld_dum
          dm = fld_dum
       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)


       fld_dum = 0.0

       ! Get normal mode transformation matrix
       ! Get normal mode frequencies

       allocate(T(3*num_atoms, 3*num_atoms))

       allocate(nm_freq_b(3*num_atoms))

       nm_freq_b = 0.0

       call load_vib_modes(3*num_atoms, n_nm, nm_freq_b, T)

       allocate(nm_freq(n_nm))

       nm_freq = 0.0

       nm_freq = nm_freq_b(1:n_nm)
       deallocate(nm_freq_b)

       allocate(ff_pv(3, 3))
       allocate(fff_pv(3, 3, 3))
       allocate(ffff_pv(3, 3, 3, 3))
       allocate(egf_cart(3*num_atoms, 3))
       allocate(egf_nm(n_nm, 3))
       allocate(egff_cart(3*num_atoms, 3, 3))
       allocate(egff_nm(n_nm, 3, 3))
       allocate(egfff_cart(3*num_atoms, 3, 3, 3))
       allocate(egfff_nm(n_nm, 3, 3, 3))

       ff_pv = 0.0
       fff_pv = 0.0
       ffff_pv = 0.0
       egf_cart = 0.0
       egf_nm = 0.0
       egff_cart = 0.0
       egff_nm = 0.0
       egfff_cart = 0.0
       egfff_nm = 0.0

       ! Calculate gradient of dipole moment

       kn = (/0,1/)

       perturbation_tuple%n_perturbations = 2
       allocate(perturbation_tuple%pdim(2))
       allocate(perturbation_tuple%plab(2))
       allocate(perturbation_tuple%pid(2))
       allocate(perturbation_tuple%freq(2))

       perturbation_tuple%plab = (/'GEO ', 'EL  '/)
       perturbation_tuple%pdim = (/3*num_atoms, 3/)
       perturbation_tuple%pid = (/1, 2/)
       perturbation_tuple%freq = (/0.0d0, 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2/)

       ! ASSUME CLOSED SHELL
       call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
       call mat_init_like_and_zero(S, zeromat_already)


       call sdf_setup_datatype(S_already, S)
       call sdf_setup_datatype(D_already, D)
       call sdf_setup_datatype(F_already, F)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Egf')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Egf', status='old', action='read', iostat=ierr)

       do i = 1, 3*num_atoms
          read(258,*) fld_dum
          egf_cart(i, :) = fld_dum
       end do

       close(258)

       egf_nm = trans_cartnc_1w1d(3*num_atoms, n_nm, egf_cart, T(:,1:n_nm))

       ! Normalize dipole moment - follows procedure by AJT

       if ( ((sum(dm * dm))**0.5) < 0.00001 ) then

          dm = (/0d0, 0d0, 1d0/)

       else

          dm = dm/((sum(dm * dm))**0.5)

       end if

       do k = 1, openrsp_cfg_nr_freq_tuples

          do h = 1, 3

             ! Calculate PV contribution to polarizability

             ff_pv = alpha_pv(n_nm, nm_freq, (/ (-1.0) * &
                              openrsp_cfg_real_freqs((k - 1) * 3 + h), &
                              openrsp_cfg_real_freqs((k - 1) * 3 + h) /), dm_1d = egf_nm) 


             if (k * h == 1) then

                open(unit=259, file='alpha_pv', status='replace', action='write') 

             else

                open(unit=259, file='alpha_pv', status='old', action='write', position='append') 

             end if

             write(259,*) 'Pure vibrational output'
             write(259,*) '======================='
             write(259,*) ' '
             write(259,*) 'Frequency combination', (k - 1) * 3 + h
             write(259,*) ' '
             write(259,*) 'Frequencies w0, w1 are', (-1.0)* &
                           openrsp_cfg_real_freqs((k - 1) * 3 + h), ' ,', &
                           openrsp_cfg_real_freqs((k - 1) * 3 + h)
             write(259,*) ' '
             write(259,*) 'PV contribution to polarizability'
             write(259,*) '================================='
             write(259,*) ' '

             format_line = '(      f20.8)'
             write(format_line(2:7), '(i6)') size(ff_pv,1)

             do i = 1, 3
                write(259, format_line) real(ff_pv(i,:))
             end do
             write(259,*) ' '
             write(259,*) 'Isotropic:', real(((1.0)/(3.0)) * &
                                        (ff_pv(1,1) + ff_pv(2,2) + ff_pv(3,3)))
             ! Follows method by AJT
             write(259,*) 'Dipole^2', real(sum( (/ ((ff_pv(i,j) * dm(i) * dm(j), &
                                      i = 1, 3), j = 1, 3) /) ))
             write(259,*) ' '

             close(259)

          end do

       end do

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)


       ! Calculate gradient of polarizability

       kn = (/0,2/)

       perturbation_tuple%n_perturbations = 3
       allocate(perturbation_tuple%pdim(3))
       allocate(perturbation_tuple%plab(3))
       allocate(perturbation_tuple%pid(3))
       allocate(perturbation_tuple%freq(3))

       perturbation_tuple%plab = (/'GEO ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/3*num_atoms, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3/)
       perturbation_tuple%freq = (/0.0d0, 0.0d0, 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3/)

       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Egff')

       ! Read polarizability gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Egff', status='old', action='read', iostat=ierr)

       do i = 1, 3*num_atoms
          do j = 1, 3
             read(258,*) fld_dum
             egff_cart(i, j, :) = fld_dum
          end do
       end do

       close(258)

       egff_nm = trans_cartnc_2w1d(3*num_atoms, n_nm, egff_cart, T(:,1:n_nm))

       do k = 1, openrsp_cfg_nr_freq_tuples

          do h = 1, 3

             ! Calculate PV contribution to 1st hyperpolarizability

             if (h == 1) then

                fff_pv = beta_pv(n_nm, nm_freq, (/ (-1.0) * &
                         (openrsp_cfg_real_freqs((k - 1) * 3 + 1) + &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 2)), &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 1), &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 2) /), &
                         dm_1d = egf_nm, po_1d = egff_nm)

             elseif (h == 2) then

                fff_pv = beta_pv(n_nm, nm_freq, (/ (-1.0) * &
                         (openrsp_cfg_real_freqs((k - 1) * 3 + 1) + &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 3)), &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 1), &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 3) /), &
                         dm_1d = egf_nm, po_1d = egff_nm)

             elseif (h == 3) then

                fff_pv = beta_pv(n_nm, nm_freq, (/ (-1.0) * &
                         (openrsp_cfg_real_freqs((k - 1) * 3 + 2) + &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 3)), &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 2), &
                         openrsp_cfg_real_freqs((k - 1) * 3 + 3) /), &
                         dm_1d = egf_nm, po_1d = egff_nm)

             end if

             if (k * h == 1) then

                open(unit=259, file='beta_pv', status='replace', action='write') 

             else

                open(unit=259, file='beta_pv', status='old', action='write', position='append') 

             end if

             write(259,*) 'Pure vibrational output'
             write(259,*) '======================='
             write(259,*) ' '
             write(259,*) 'Frequency combination', (k - 1) * 3 + h
             write(259,*) ' '

             if (h == 1) then

                write(259,*) 'Frequencies w0, w1, w2 are', (-1.0) * &
                             (openrsp_cfg_real_freqs((k - 1) * 3 + 1) + &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 2)), ' ,', &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 1), ' ,', &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 2)

             elseif (h == 2) then

                write(259,*) 'Frequencies w0, w1, w2 are', (-1.0) * &
                             (openrsp_cfg_real_freqs((k - 1) * 3 + 1) + &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 3)), ' ,', &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 1), ' ,', &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 3)

             elseif (h == 3) then

                write(259,*) 'Frequencies w0, w1, w2 are', (-1.0) * &
                             (openrsp_cfg_real_freqs((k - 1) * 3 + 2) + &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 3)), ' ,', &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 2), ' ,', &
                             openrsp_cfg_real_freqs((k - 1) * 3 + 3)

             end if


             write(259,*) ' '
             write(259,*) 'PV contribution to 1st hyperpolarizability'
             write(259,*) '=========================================='
             write(259,*) ' '

             format_line = '(      f20.8)'
             write(format_line(2:7), '(i6)') size(ff_pv,1)

             do i = 1, 3
                do j = 1, 3
                   write(259, format_line) real(fff_pv(i,j,:))
                end do
                write(259,*) ' '
             end do
             ! Follows method by AJT
             write(259,*) 'Isotropic:', real(((1.0)/(5.0)) * sum ( (/ (((fff_pv(i,i,j) + &
                                        fff_pv(i,j,i) + fff_pv(j,i,i)) * dm(j), &
                                        i = 1, 3), j = 1, 3) /)))
             ! Follows method by AJT
             write(259,*) 'Dipole^3', real(sum( (/ (((fff_pv(i,j,k) * dm(i) * dm(j) * dm(k), &
                                      i = 1, 3), j = 1, 3), k = 1, 3) /) ))
             write(259,*) ' '

             close(259)

          end do

       end do

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

       ! Calculate gradient of first hyperpolarizability

       kn = (/0,3/)

       perturbation_tuple%n_perturbations = 4
       allocate(perturbation_tuple%pdim(4))
       allocate(perturbation_tuple%plab(4))
       allocate(perturbation_tuple%pid(4))
       allocate(perturbation_tuple%freq(4))

       perturbation_tuple%plab = (/'GEO ', 'EL  ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/3*num_atoms, 3, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3, 4/)
       perturbation_tuple%freq = (/0.0d0, 0.0d0, 0.0d0, 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3, 4/)

       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Egfff')

       ! Read 1st hyperpolarizability gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Egfff', status='old', action='read', iostat=ierr)

       do i = 1, 3*num_atoms
          do j = 1, 3
             do k = 1, 3
                read(258,*) fld_dum
                egfff_cart(i, j, k, :) = fld_dum
             end do
          end do
       end do

       close(258)

       egfff_nm = trans_cartnc_3w1d(3*num_atoms, n_nm, egfff_cart, T(:,1:n_nm))

       ! Calculate PV contribution to 2nd hyperpolarizability


       do k = 1, openrsp_cfg_nr_freq_tuples

          ffff_pv = gamma_pv(n_nm, nm_freq, (/ (-1.0) * &
                             sum(openrsp_cfg_real_freqs((k-1)*3 + 1: (k-1)*3 + 3)), &
                             openrsp_cfg_real_freqs((k-1)*3 + 1), &
                             openrsp_cfg_real_freqs((k-1)*3 + 2), &
                             openrsp_cfg_real_freqs((k-1)*3 + 3)/), &
                             dm_1d = egf_nm, po_1d = egff_nm, hp_1d = egfff_nm) 


          if (k == 1) then

             open(unit=259, file='gamma_pv', status='replace', action='write') 

          else

             open(unit=259, file='gamma_pv', status='old', action='write', position='append') 

          end if

          write(259,*) 'Pure vibrational output'
          write(259,*) '======================='
          write(259,*) ' '
          write(259,*) 'Frequency combination', k
          write(259,*) ' '
          write(259,*) 'Frequencies w0, w1, w2, w3 are', (-1.0) * &
                       sum(openrsp_cfg_real_freqs((k-1)*3 + 1: (k-1)*3 + 3)), ' ,', &
                       openrsp_cfg_real_freqs((k-1)*3 + 1), ' ,', &
                       openrsp_cfg_real_freqs((k-1)*3 + 2), ' ,', &
                       openrsp_cfg_real_freqs((k-1)*3 + 3)
          write(259,*) ' '
          write(259,*) 'PV contribution to 2nd hyperpolarizability'
          write(259,*) '=========================================='
          write(259,*) ' '
          format_line = '(      f20.8)'
          write(format_line(2:7), '(i6)') size(ff_pv,1)

          do i = 1, 3
             do j = 1, 3
                do m = 1, 3
                   write(259, format_line) real(ffff_pv(i,j,m,:))
                end do 
                write(259,*) ' '
             end do
             write(259,*) ' '
          end do
          ! Follows method by AJT
          write(259,*) 'Isotropic:', real(((1.0)/(15.0)) * sum ((/ ((ffff_pv(i,i,j,j) + &
                       ffff_pv(i,j,i,j) + ffff_pv(i,j,j,i), i = 1, 3), j = 1, 3) /)))
          ! Follows method by AJT
          write(259,*) 'Dipole^4', real(sum( (/ ((((ffff_pv(i,j,k,m) * dm(i) * dm(j) * dm(k) * &
                                   dm(m), i = 1, 3), j = 1, 3), k = 1, 3), m = 1, 3) /) ))
          write(259,*) ' '

          close(259)

       end do

       deallocate(T)
       deallocate(nm_freq)
       deallocate(ff_pv)
       deallocate(fff_pv)
       deallocate(ffff_pv)
       deallocate(egf_cart)
       deallocate(egf_nm)
       deallocate(egff_cart)
       deallocate(egff_nm)
       deallocate(egfff_cart)
       deallocate(egfff_nm)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

    end if

    if (openrsp_cfg_general_hyper_raman) then

       ! Verify the value of the conversion factor
       reccm = 219474.6313705d0
       fld_dum = 0.0

       ! Get normal mode transformation matrix
       ! Get normal mode frequencies

       allocate(T(3*num_atoms, 3*num_atoms))

       allocate(nm_freq_b(3*num_atoms))

       nm_freq_b = 0.0

       call load_vib_modes(3*num_atoms, n_nm, nm_freq_b, T)

       allocate(nm_freq(n_nm))

       nm_freq = nm_freq_b(1:n_nm) * openrsp_cfg_general_hypram_freqscale
       
       deallocate(nm_freq_b)

       allocate(egfff_cart(3*num_atoms, 3, 3, 3))
       allocate(egfff_nm(n_nm, 3, 3, 3))
       allocate(hr_intensities_hv(n_nm))
       allocate(hr_intensities_vv(n_nm))

       ! Calculate gradient of first hyperpolarizability

       kn = (/0,3/)

       perturbation_tuple%n_perturbations = 4
       allocate(perturbation_tuple%pdim(4))
       allocate(perturbation_tuple%plab(4))
       allocate(perturbation_tuple%pid(4))
       allocate(perturbation_tuple%freq(4))

       perturbation_tuple%plab = (/'GEO ', 'EL  ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/3*num_atoms, 3, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3, 4/)
       perturbation_tuple%freq = (/0.0d0, -2.0d0* openrsp_cfg_real_freqs(1),&
                       openrsp_cfg_real_freqs(1), openrsp_cfg_real_freqs(1)/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3, 4/)

       ! ASSUME CLOSED SHELL
       call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
       call mat_init_like_and_zero(S, zeromat_already)


       call sdf_setup_datatype(S_already, S)
       call sdf_setup_datatype(D_already, D)
       call sdf_setup_datatype(F_already, F)



       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Egfff')

       ! Read 1st hyperpolarizability gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Egfff', status='old', action='read', iostat=ierr)

       do i = 1, 3*num_atoms
          do j = 1, 3
             do k = 1, 3
                read(258,*) fld_dum
                egfff_cart(i, j, k, :) = fld_dum
             end do
          end do
       end do

       close(258)

       egfff_nm = trans_cartnc_3w1d(3*num_atoms, n_nm, egfff_cart, T(:,1:n_nm))

       open(unit = 12, file='hr_output', status='replace', action='write', iostat=ierr)

       write(12,*) 'HYPER-RAMAN INTENSITY OUTPUT'
       write(12,*) '============================'
       write(12,*) ' '
       ! Write something about time and date
       ! Adapt frequency to multiple frequency tuple setup
       write(12,100) openrsp_cfg_real_freqs(1)
       100 format('The Hyper-Raman intensities are calculated using an electronic frequency of ', &
       F10.7, ' a.u.')
       write(12,*) ' '

       write(12,101) openrsp_cfg_temperature
       101 format('The temperature is set at', F10.5 ' K.')
       write(12,*) ' '
       
       write(12,102) n_nm
       102 format('The number of normal modes considered in this system is', I5, ' .')
       write(12,*) 'These modes have the following frequencies:'
       write(12,*) ' '

       write(12,*) 'Mode      Frequency (a.u.)'
       write(12,*) '=========================='
       write(12,*) ' '

       do i = 1, n_nm
          write(12,103) i, nm_freq(i)
          103 format(I6, 4X, F10.7)
       end do


       write(12,*) ' '

       write(12,120) openrsp_cfg_general_hypram_freqscale
       120 format('The frequencies are all scaled by a factor of', F10.5, ' .')
       write(12,*) ' '


       ! Calculate the intensities mode by mode

       ! Adapt frequency to multiple frequency tuple setup
       do i = 1, n_nm
          hr_intensities_hv(i) = hyp_raman_hv(n_nm, openrsp_cfg_temperature, &
                                 openrsp_cfg_real_freqs(1), nm_freq(i), dreal(egfff_nm(i, :, :, :)))
       end do

       write(12,*) 'HR intensities using HV polarization:'
       write(12,*) ' '
       write(12,*) 'Mode        Freq. (a.u.)    Freq (cm^-1)      Intensity '
       write(12,*) '====================================================================='
       write(12,*) ' '

       do i = 1, n_nm
          write(12,114) i, nm_freq(i), nm_freq(i)*reccm, hr_intensities_hv(i)
          114 format(I5, 4X, F13.7, 6X, F13.7, 4X, F25.10)
       end do
       write(12,*) ' '

       ! Adapt frequency to multiple frequency tuple setup
       do i = 1, n_nm
          hr_intensities_vv(i) = hyp_raman_vv(n_nm, openrsp_cfg_temperature, &
                                 openrsp_cfg_real_freqs(1), nm_freq(i), dreal(egfff_nm(i, :, :, :)))
       end do

       write(12,*) 'HR intensities using VV polarization:'
       write(12,*) ' '
       write(12,*) 'Mode        Freq. (a.u.)    Freq (cm^-1)      Intensity '
       write(12,*) '====================================================================='
       write(12,*) ' '

       do i = 1, n_nm
          write(12,115) i, nm_freq(i), nm_freq(i)*reccm, hr_intensities_vv(i)
          115 format(I5, 4X, F13.7, 6X, F13.7, 4X, F25.10)
       end do
       write(12,*) ' '
       close(12)

       deallocate(hr_intensities_hv)
       deallocate(hr_intensities_vv)
       deallocate(nm_freq)
       deallocate(T)

    end if

! MaR: This routine is untested
    if (openrsp_cfg_general_efishgcid) then

       
       ! FIND CORRECT VALUE: AROUND 137?
       c0 = 1.0

       fld_dum = 0.0


       Effff = 0.0
       Effmfww = 0.0
       Effmfw2w = 0.0
       Effqfww = 0.0
       Effqfw2w = 0.0

       ! ASSUME CLOSED SHELL
       call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
       call mat_init_like_and_zero(S, zeromat_already)

       call sdf_setup_datatype(S_already, S)
       call sdf_setup_datatype(D_already, D)
       call sdf_setup_datatype(F_already, F)

do k = 1, openrsp_cfg_nr_freq_tuples

       ! Calculate Effff(w, w, 0)

       kn = (/1,2/)

       perturbation_tuple%n_perturbations = 4
       allocate(perturbation_tuple%pdim(4))
       allocate(perturbation_tuple%plab(4))
       allocate(perturbation_tuple%pid(4))
       allocate(perturbation_tuple%freq(4))

       perturbation_tuple%plab = (/'EL  ', 'EL  ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/3, 3, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3, 4/)
       perturbation_tuple%freq = (/-2.0d0 * openrsp_cfg_real_freqs(k), &
       openrsp_cfg_real_freqs(k), openrsp_cfg_real_freqs(k), 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3, 4/)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, file_id='Effff')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Effff', status='old', action='read', iostat=ierr)

       do i = 1, 3
          do j = 1, 3
             do m = 1, 3
                read(258,*) fld_dum
                Effff(i, j, m, :) = fld_dum
             end do
          end do
       end do

       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)


       ! Calculate Effmf(w, w, 0)

       kn = (/0,3/)

       perturbation_tuple%n_perturbations = 4
       allocate(perturbation_tuple%pdim(4))
       allocate(perturbation_tuple%plab(4))
       allocate(perturbation_tuple%pid(4))
       allocate(perturbation_tuple%freq(4))

       perturbation_tuple%plab = (/'MAG ', 'EL  ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/3, 3, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3, 4/)
       perturbation_tuple%freq = (/openrsp_cfg_real_freqs(k), &
       openrsp_cfg_real_freqs(k),  -2.0d0 * openrsp_cfg_real_freqs(k), 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3, 4/)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, &
                           file_id='Emfffww')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Emfffww', status='old', action='read', iostat=ierr)

! IMPORTANT: FIND OUT HOW TUPLES ARE SORTED AND READ IN ACCORDINGLY (IT MAY ALREADY BE CORRECT)
       do i = 1, 3
          do j = 1, 3
             do m = 1, 3
                read(258,*) fld_dum
                Effmfww(m, j, i, :) = fld_dum
             end do
          end do
       end do

       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

       ! Calculate Effmf(w, -2w, 0)

       kn = (/0,3/)

       perturbation_tuple%n_perturbations = 4
       allocate(perturbation_tuple%pdim(4))
       allocate(perturbation_tuple%plab(4))
       allocate(perturbation_tuple%pid(4))
       allocate(perturbation_tuple%freq(4))

       perturbation_tuple%plab = (/'EL  ', 'EL  ', 'MAG ', 'EL  '/)
       perturbation_tuple%pdim = (/3, 3, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3, 4/)
       perturbation_tuple%freq = (/-2.0d0 * openrsp_cfg_real_freqs(k), &
       openrsp_cfg_real_freqs(k), openrsp_cfg_real_freqs(k), 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3, 4/)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, &
                           file_id='Effmfw2w')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Effmfw2w', status='old', action='read', iostat=ierr)

! IMPORTANT: FIND OUT HOW TUPLES ARE SORTED AND READ IN ACCORDINGLY (IT MAY ALREADY BE CORRECT)
       do i = 1, 3
          do j = 1, 3
             do m = 1, 3
                read(258,*) fld_dum
                Effmfw2w(m, j, i, :) = fld_dum
             end do
          end do
       end do

       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)






       ! Calculate Effqf(w, w, 0)

       kn = (/0,3/)

       perturbation_tuple%n_perturbations = 4
       allocate(perturbation_tuple%pdim(4))
       allocate(perturbation_tuple%plab(4))
       allocate(perturbation_tuple%pid(4))
       allocate(perturbation_tuple%freq(4))

       perturbation_tuple%plab = (/'ELGR', 'EL  ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/6, 3, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3, 4/)
       perturbation_tuple%freq = (/openrsp_cfg_real_freqs(k), &
       openrsp_cfg_real_freqs(k), -2.0d0 * openrsp_cfg_real_freqs(k), 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3, 4/)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, &
                           file_id='Effqfww')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Effqfww', status='old', action='read', iostat=ierr)

! IMPORTANT: FIND OUT HOW TUPLES ARE SORTED AND READ IN ACCORDINGLY (IT MAY ALREADY BE CORRECT)
       do i = 1, 3
          do j = 1, 3
             do m = 1, 3
                read(258,*) fld_dum
                Effqfww(m, j, i, :) = fld_dum
             end do
          end do
       end do

       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

       ! Calculate Effqf(w, -2w, 0)

       kn = (/0,3/)

       perturbation_tuple%n_perturbations = 4
       allocate(perturbation_tuple%pdim(4))
       allocate(perturbation_tuple%plab(4))
       allocate(perturbation_tuple%pid(4))
       allocate(perturbation_tuple%freq(4))

       perturbation_tuple%plab = (/'ELGR', 'EL  ', 'EL  ', 'EL  '/)
       perturbation_tuple%pdim = (/6, 3, 3, 3/)
       perturbation_tuple%pid = (/1, 2, 3, 4/)
       perturbation_tuple%freq = (/-2.0d0 * openrsp_cfg_real_freqs(k), &
       openrsp_cfg_real_freqs(k), openrsp_cfg_real_freqs(k), 0.0d0/)

       perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
       perturbation_tuple%pid = (/1, 2, 3, 4/)


       call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
                           S_already=S_already, zeromat_already=zeromat_already, &
                           file_id='Effqfw2w')


       ! Read dipole moment gradient from file and transform to normal mode basis

       open(unit = 258, file='rsp_tensor_Effqfw2w', status='old', action='read', iostat=ierr)

! IMPORTANT: FIND OUT HOW TUPLES ARE SORTED AND READ IN ACCORDINGLY (IT MAY ALREADY BE CORRECT)
       do i = 1, 3
          do j = 1, 3
             do m = 1, 3
                read(258,*) fld_dum
                Effqfw2w(m, j, i, :) = fld_dum
             end do
          end do
       end do

       close(258)

       deallocate(perturbation_tuple%pdim)
       deallocate(perturbation_tuple%plab)
       deallocate(perturbation_tuple%pid)
       deallocate(perturbation_tuple%freq)

do i = 1, 3

 CID(i) = (1.0/c0) * ( M_efishg(i, Effff, Effmfww, Effmfw2w) + &
          openrsp_cfg_real_freqs(k) *  L_efishg(i, Effff, Effqfww, Effqfw2w) ) / &
          ( D_efishg(setup_i, Effff) )

end do


! Add output printing





end do

    end if







! ! MaR: This routine is untested
! ! Get SFG point intensities in the double harmonic approximation
!     if (openrsp_cfg_general_sfg) then
! 
!        ! Get Egf 
!        ! Get Egff (which frequency/frequencies?)
! 
! ! Get vibrational information and convert tensors to normal mode basis
! ! All of the above should be easily adaptable from the pv_beta code
! 
!        ! Calculate dipole moment
! 
!        kn = (/0,0/)
! 
!        perturbation_tuple%n_perturbations = 1
!        allocate(perturbation_tuple%pdim(1))
!        allocate(perturbation_tuple%plab(1))
!        allocate(perturbation_tuple%pid(1))
!        allocate(perturbation_tuple%freq(1))
! 
!        perturbation_tuple%plab = (/'EL  '/)
!        perturbation_tuple%pdim = (/3/)
!        perturbation_tuple%pid = (/1/)
!        perturbation_tuple%freq = (/0.0d0/)
! 
!        call rsp_prop(perturbation_tuple, kn, F, D, S, file_id='Ef')
! 
!        ! Read dipole moment from file
! 
!        open(unit = 258, file='rsp_tensor_Ef', status='old', action='read', iostat=ierr)
!        read(258,*) fld_dum
!           dm = fld_dum
!        close(258)
! 
!        deallocate(perturbation_tuple%pdim)
!        deallocate(perturbation_tuple%plab)
!        deallocate(perturbation_tuple%pid)
!        deallocate(perturbation_tuple%freq)
! 
!        fld_dum = 0.0
! 
!        ! Get normal mode transformation matrix
!        ! Get normal mode frequencies
! 
!        allocate(T(3*num_atoms, 3*num_atoms))
! 
!        allocate(nm_freq_b(3*num_atoms))
! 
!        nm_freq_b = 0.0
! 
!        call load_vib_modes(3*num_atoms, n_nm, nm_freq_b, T)
! 
!        allocate(nm_freq(n_nm))
! 
!        nm_freq = 0.0
! 
!        nm_freq = nm_freq_b(1:n_nm)
!        deallocate(nm_freq_b)
! 
!        allocate(ff_pv(3, 3))
!        allocate(fff_pv(3, 3, 3))
!        allocate(egf_cart(3*num_atoms, 3))
!        allocate(egf_nm(n_nm, 3))
!        allocate(egff_cart(3*num_atoms, 3, 3))
!        allocate(egff_nm(n_nm, 3, 3))
! 
!        ff_pv = 0.0
!        fff_pv = 0.0
!        egf_cart = 0.0
!        egf_nm = 0.0
!        egff_cart = 0.0
!        egff_nm = 0.0
! 
!        ! Calculate gradient of dipole moment
! 
!        kn = (/0,1/)
! 
!        perturbation_tuple%n_perturbations = 2
!        allocate(perturbation_tuple%pdim(2))
!        allocate(perturbation_tuple%plab(2))
!        allocate(perturbation_tuple%pid(2))
!        allocate(perturbation_tuple%freq(2))
! 
!        perturbation_tuple%plab = (/'GEO ', 'EL  '/)
!        perturbation_tuple%pdim = (/3*num_atoms, 3/)
!        perturbation_tuple%pid = (/1, 2/)
!        perturbation_tuple%freq = (/0.0d0, 0.0d0/)
! 
!        perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
!        perturbation_tuple%pid = (/1, 2/)
! 
!        ! ASSUME CLOSED SHELL
!        call mat_init(zeromat_already, S%nrow, S%ncol, is_zero=.true.)
!        call mat_init_like_and_zero(S, zeromat_already)
! 
! 
!        call sdf_setup_datatype(S_already, S)
!        call sdf_setup_datatype(D_already, D)
!        call sdf_setup_datatype(F_already, F)
! 
! 
!        call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
!                            S_already=S_already, zeromat_already=zeromat_already, file_id='Egf')
! 
! 
!        ! Read dipole moment gradient from file and transform to normal mode basis
! 
!        open(unit = 258, file='rsp_tensor_Egf', status='old', action='read', iostat=ierr)
! 
!        do i = 1, 3*num_atoms
!           read(258,*) fld_dum
!           egf_cart(i, :) = fld_dum
!        end do
! 
!        close(258)
! 
!        egf_nm = trans_cartnc_1w1d(3*num_atoms, n_nm, egf_cart, T(:,1:n_nm))
! 
! 
!        ! Normalize dipole moment - follows procedure by AJT
! 
!        if ( ((sum(dm * dm))**0.5) < 0.00001 ) then
! 
!           dm = (/0d0, 0d0, 1d0/)
! 
!        else
! 
!           dm = dm/((sum(dm * dm))**0.5)
! 
!        end if
! 
! 
! 
!        deallocate(perturbation_tuple%pdim)
!        deallocate(perturbation_tuple%plab)
!        deallocate(perturbation_tuple%pid)
!        deallocate(perturbation_tuple%freq)
! 
!        do k = 1, openrsp_cfg_nr_freq_tuples
! 
!           ! Calculate gradient of polarizability
! 
!           kn = (/0,2/)
! 
!           perturbation_tuple%n_perturbations = 3
!           allocate(perturbation_tuple%pdim(3))
!           allocate(perturbation_tuple%plab(3))
!           allocate(perturbation_tuple%pid(3))
!           allocate(perturbation_tuple%freq(3))
! 
!           perturbation_tuple%plab = (/'GEO ', 'EL  ', 'EL  '/)
!           perturbation_tuple%pdim = (/3*num_atoms, 3, 3/)
!           perturbation_tuple%pid = (/1, 2, 3/)
!           perturbation_tuple%freq = (/0.0d0, -1.0d0 * openrsp_cfg_real_freqs(k), &
!                                                       openrsp_cfg_real_freqs(k)/)
! 
!           perturbation_tuple = p_tuple_standardorder(perturbation_tuple)
!           perturbation_tuple%pid = (/1, 2, 3/)
! 
! 
!           call rsp_prop(perturbation_tuple, kn, F_already=F_already, D_already=D_already, &
!                               S_already=S_already, zeromat_already=zeromat_already, file_id='Egff')
! 
!           ! Read polarizability gradient from file and transform to normal mode basis
! 
!           open(unit = 258, file='rsp_tensor_Egff', status='old', action='read', iostat=ierr)
! 
!           do i = 1, 3*num_atoms
!              do j = 1, 3
!                 read(258,*) fld_dum
!                 egff_cart(i, j, :) = fld_dum
!              end do
!           end do
! 
!           close(258)
! 
!           egff_nm = trans_cartnc_2w1d(3*num_atoms, n_nm, egff_cart, T(:,1:n_nm))
! 
!           deallocate(perturbation_tuple%pdim)
!           deallocate(perturbation_tuple%plab)
!           deallocate(perturbation_tuple%pid)
!           deallocate(perturbation_tuple%freq)
! 
!           do m = 1, n_nm
! 
!              sfg_intensity(i) = 
! 
!           end do
! 
! 
! 
! 
!        end do
! 
!        deallocate(T)
!        deallocate(nm_freq)
!        deallocate(ff_pv)
!        deallocate(fff_pv)
!        deallocate(egf_cart)
!        deallocate(egf_nm)
!        deallocate(egff_cart)
!        deallocate(egff_nm)
! 
! 
! 
! 
! ! Loop over modes, calculate point intensities
!       
! 
!     end if









  end subroutine

  subroutine openrsp_finalize()
    integer lupri
    lupri = get_print_unit()
    ! free

    S = 0
    D = 0
    F = 0

    call rsp_mosolver_finalize()
    if (get_is_pcm_calculation()) then
       call interface_pcm_finalize()
    end if
    call interface_f77_memory_finalize()
    ! stamp with date, time and hostname
    call TSTAMP(' ', lupri)
    write (lupri,*)
    write (lupri,*) '>> ** End of OpenRSP Section'
    write (lupri,*)
  end subroutine

end module

!> \brief driver used for DALTON
!> \author Bin Gao
!> \date 2009-12-08
!> \param WORK contains the work memory
!> \param LWORK is the size of the work memory
subroutine openrsp_driver(work, lwork, wavpcm)

   use openrsp

   implicit none

   integer, intent(in)    :: lwork
   real(8), intent(inout) :: work(lwork)
   logical, intent(in)    :: wavpcm

   call openrsp_setup(wavpcm, lwork, work)
   call openrsp_calc()
   call openrsp_finalize()

end subroutine
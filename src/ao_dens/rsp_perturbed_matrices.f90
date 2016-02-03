! Copyright 2012 Magnus Ringholm
!
! This file is made available under the terms of the
! GNU Lesser General Public License version 3.

! Contains routines and functions for the calculation of (perturbed) matrices,
! arising in the response equations, that use (perturbed) S, D, and F
! as building blocks. These matrices are W, Y, Z, Lambda, and Zeta.

module rsp_perturbed_matrices

!  use matrix_defop, matrix => openrsp_matrix
!  use matrix_lowlevel, only: mat_init
  use rsp_field_tuple, only: p_tuple,              &
                             p_tuple_extend,       &
                             p_tuple_getone,       &
                             merge_p_tuple,        &
                             p_tuple_remove_first, &
                             p_tuple_deallocate
  use rsp_sdf_caching
  use rsp_indices_and_addressing
  use rsp_property_caching
  use qcmatrix_f

  implicit none

  public derivative_superstructure_getsize
  public derivative_superstructure
  public get_fds_data_index
  public frequency_zero_or_sum
  
  public rsp_get_matrix_w_2014
  public rsp_get_matrix_y_2014
  public rsp_get_matrix_z_2014
  public rsp_get_matrix_lambda_2014
  public rsp_get_matrix_zeta_2014
  public rsp_get_matrix_w
  public rsp_get_matrix_y
  public rsp_get_matrix_z
  public rsp_get_matrix_lambda
  public rsp_get_matrix_zeta

!  type rsp_cfg
!
!     type(matrix) :: zeromat
!
!  end type
  contains

  recursive function derivative_superstructure_getsize(pert, kn, &
                     primed, current_derivative_term) result(superstructure_size)

    implicit none

    logical :: primed
!    type(matrix) :: zeromat
    type(p_tuple) :: pert
    type(p_tuple), dimension(3) :: current_derivative_term
    integer, dimension(2) :: kn
    integer :: i, superstructure_size

    superstructure_size = 0

    if (pert%npert > 0) then

       superstructure_size = superstructure_size + derivative_superstructure_getsize( &
                             p_tuple_remove_first(pert), kn, primed, &
                             (/p_tuple_extend(current_derivative_term(1), &
                             p_tuple_getone(pert, 1)), current_derivative_term(2:3)/))

       superstructure_size = superstructure_size + derivative_superstructure_getsize( &
                             p_tuple_remove_first(pert), kn, primed, &
                             (/current_derivative_term(1), &
                             p_tuple_extend(current_derivative_term(2), &
                             p_tuple_getone(pert,1)), current_derivative_term(3)/))

       superstructure_size = superstructure_size + derivative_superstructure_getsize( &
                             p_tuple_remove_first(pert), kn, primed, &
                             (/current_derivative_term(1:2), &
                             p_tuple_extend(current_derivative_term(3), &
                             p_tuple_getone(pert, 1))/))

    else

       if (primed .EQV. .TRUE.) then

          if ( ( ( (current_derivative_term(1)%npert <= kn(2)) .AND.&
              current_derivative_term(2)%npert <= kn(2) ) .AND. &
              current_derivative_term(3)%npert <= kn(2) ) .eqv. .TRUE.) then

             superstructure_size = 1

          else

             superstructure_size = 0

          end if

       else

          if ( ( (kn_skip(current_derivative_term(1)%npert, current_derivative_term(1)%pid, kn) .OR. &
                  kn_skip(current_derivative_term(2)%npert, current_derivative_term(2)%pid, kn) ) .OR. &
                  kn_skip(current_derivative_term(3)%npert, current_derivative_term(3)%pid, kn) ) .eqv. &
                  .FALSE.) then

             superstructure_size = 1

          else

             superstructure_size = 0

          end if

       end if

    end if

  end function


  recursive subroutine derivative_superstructure(pert, kn, primed, &
                       current_derivative_term, superstructure_size, & 
                       new_element_position, derivative_structure)

    implicit none

    logical :: primed
    integer :: i, superstructure_size, new_element_position
    integer, dimension(2) :: kn    
!    type(matrix) :: zeromat
    type(p_tuple) :: pert
    type(p_tuple), dimension(3) :: current_derivative_term
    type(p_tuple), dimension(superstructure_size, 3) :: derivative_structure

    if (pert%npert > 0) then

       call derivative_superstructure(p_tuple_remove_first(pert), kn, primed, &
            (/p_tuple_extend(current_derivative_term(1), p_tuple_getone(pert, 1)), &
            current_derivative_term(2:3)/), superstructure_size, new_element_position, &
            derivative_structure)

       call derivative_superstructure(p_tuple_remove_first(pert), kn, primed, &
            (/current_derivative_term(1), p_tuple_extend(current_derivative_term(2), &
            p_tuple_getone(pert, 1)), current_derivative_term(3)/), &
            superstructure_size, new_element_position, derivative_structure)

       call derivative_superstructure(p_tuple_remove_first(pert), kn, primed, &
            (/current_derivative_term(1:2), p_tuple_extend(current_derivative_term(3), &
            p_tuple_getone(pert, 1))/), superstructure_size, new_element_position, &
            derivative_structure)

    else


       if (primed .EQV. .TRUE.) then

          if ( ( ( (current_derivative_term(1)%npert <= kn(2)) .AND.&
              current_derivative_term(2)%npert <= kn(2) ) .AND. &
              current_derivative_term(3)%npert <= kn(2) ) .eqv. .TRUE.) then

             new_element_position = new_element_position + 1
             derivative_structure(new_element_position, :) = current_derivative_term
 
          end if

       else

          if ( ( (kn_skip(current_derivative_term(1)%npert,  &
                          current_derivative_term(1)%pid, kn) .OR. &
                  kn_skip(current_derivative_term(2)%npert,  &
                          current_derivative_term(2)%pid, kn) ) .OR. &
                  kn_skip(current_derivative_term(3)%npert, &
                          current_derivative_term(3)%pid, kn) ) .eqv. .FALSE.) then

             new_element_position = new_element_position + 1 
             derivative_structure(new_element_position, :) = current_derivative_term(:)

          end if

       end if

    end if

  end subroutine


! BEGIN NEW 2015

! BEGIN NEW 2014

subroutine rsp_get_matrix_w(superstructure_size, &
           deriv_struct, total_num_perturbations, which_index_is_pid, &
           indices_len, ind, F, D, S, W)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(contrib_cache_outer) :: F, D, S
    type(QcMat) :: W, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size

!        call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(F, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!        call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)
            
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
       call contrib_cache_getdata_outer(F, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B)                
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)       

!      W = W + A * B * C
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, W)
            


       if (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

!           call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!           call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!           call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)
               
          call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B)                
          call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)               
               

!            W = W + ((1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) - &
!                                    frequency_zero_or_sum(deriv_struct(i,3))) * A * B * C
               
          call QcMatcABC(((1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) - &
                        frequency_zero_or_sum(deriv_struct(i,3))), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, W)
               
         
       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

!           call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!           call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!           call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)

          call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B)                
          call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)               

!           W = W + ((1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)) * A * B * C
               
          call QcMatcABC(((1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, W)
               


       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,1)) == 0.0)) then

!           call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!           call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!           call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)
               
          call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B)                
          call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)                

!           W = W + ((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3))  * A * B * C

          call QcMatcABC(((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, W)   
          
       end if

    end do

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)

  end subroutine


  subroutine rsp_get_matrix_y(superstructure_size, deriv_struct, &
           total_num_perturbations, which_index_is_pid, indices_len, &
           ind, F, D, S, Y)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len, j
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(contrib_cache_outer) :: F, D, S
    type(QcMat) :: Y, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)
    
    do i = 1, superstructure_size
   
!        write(*,*) 'Deriv struct', i
!    
!        do j = 1, 3
!          write(*,*) j, ':', deriv_struct(i,j)%plab
!          
!        
!        end do
    

!        call sdf_getdata_s_2014(F, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(D, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!        call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)
            
       call contrib_cache_getdata_outer(F, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)             
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B)             
       call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C) 
!        Y = Y + A*B*C

!        if (i == 1) then
!        
!          j = QcMatWrite_f(A, 'Y_F', ASCII_VIEW)
!          j = QcMatWrite_f(B, 'Y_D', ASCII_VIEW)
!          j = QcMatWrite_f(C, 'Y_S', ASCII_VIEW)
! 
!        
!        end if
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Y)
!        stop
!        if (i == 1) then
!        
!          j = QcMatWrite_f(Y, 'Y_tmp_a', ASCII_VIEW)
!          
!        
!        end if
       

       if (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
               
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)

!           Y = Y - frequency_zero_or_sum(deriv_struct(i,2)) * A * B * C

          call QcMatcABC(-1.0 * frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)
          
       end if

!        call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(F, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)

       call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)  
       call contrib_cache_getdata_outer(F, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)  
                       

!        Y = Y - A * B * C
        
       call QcMatkABC(-1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Y)

!             if (i == 1) then
!        
!          j = QcMatWrite_f(Y, 'Y_tmp_b', ASCII_VIEW)
!          
!        
!        end if
       

       if (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then
          ! MaR: MAKE SURE THAT THESE (AND B) ARE ACTUALLY THE CORRECT 
          ! MATRICES TO USE HERE AND BELOW

!           call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!           call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)

          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)  
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)  
       
               
!           Y = Y + ((-1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) + &
!                                     frequency_zero_or_sum(deriv_struct(i,3))) * A * B * C
                                    
          call QcMatcABC(((-1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) + &
                                    frequency_zero_or_sum(deriv_struct(i,3))), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)


       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
             (frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!           call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)
               
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)  
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)  
         

!           Y = Y + ((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)) * A * B * C
          
          call QcMatcABC(((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)


       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,1)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!           call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)
               
          call contrib_cache_getdata_outer(S, 1, (/ deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)  
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)  

               
!           Y = Y + ((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3)) * A * B * C

          call QcMatcABC(((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)

       end if

    end do

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine


  subroutine rsp_get_matrix_z(superstructure_size, deriv_struct, kn, &
           total_num_perturbations, which_index_is_pid, indices_len, &
           ind, F, D, S, Z)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    type(p_tuple) :: merged_p_tuple
    integer, dimension(2) :: kn
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(contrib_cache_outer) :: F, D, S
    type(QcMat) :: Z, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size

!        call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!        call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)
            
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
       call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B)             
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)             
!        Z = Z + A*B*C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Z)

    end do

    merged_p_tuple = merge_p_tuple(deriv_struct(1,1), merge_p_tuple(deriv_struct(1,2), deriv_struct(1,3)))

    if (kn_skip(total_num_perturbations, merged_p_tuple%pid, kn) .eqv. .FALSE.) then


!         call sdf_getdata_s_2014(D, merged_p_tuple, get_fds_data_index(merged_p_tuple, &
!         total_num_perturbations, which_index_is_pid, indices_len, ind), A)

       call contrib_cache_getdata_outer(D, 1, (/merged_p_tuple/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_p_tuple, &
        total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
            
!         Z = Z - A
        
        call QcMatRAXPY(-1.0d0, A, Z)

    end if

    call p_tuple_deallocate(merged_p_tuple)

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine


  subroutine rsp_get_matrix_lambda(p_tuple_a, superstructure_size, deriv_struct, &
           total_num_perturbations, which_index_is_pid, indices_len, ind, D, S, L)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple) :: p_tuple_a, merged_A, merged_B
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(contrib_cache_outer) :: D, S
    type(QcMat) :: L, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size

       merged_A = merge_p_tuple(p_tuple_a, deriv_struct(i,1))
       merged_B = merge_p_tuple(p_tuple_a, deriv_struct(i,3))

!        call sdf_getdata_s_2014(D, merged_A, get_fds_data_index(merged_A, &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!        call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)

       call contrib_cache_getdata_outer(D, 1, (/merged_A/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_A, &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
       call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B) 
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)             
!        L = L + A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, L)            
            

        
!        call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(D, merged_B, get_fds_data_index(merged_B, &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)
            
            
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
       call contrib_cache_getdata_outer(D, 1, (/merged_B/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_B, &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)             

!        L = L - A * B * C
       
       call QcMatkABC(-1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, L)    

       call p_tuple_deallocate(merged_A)
       call p_tuple_deallocate(merged_B)
       
    end do
    
    
    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine


  subroutine rsp_get_matrix_zeta(p_tuple_a, kn, superstructure_size, deriv_struct, &
           total_num_perturbations, which_index_is_pid, indices_len, &
           ind, F, D, S, Zeta)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len, j
    type(p_tuple) :: p_tuple_a, merged_p_tuple, merged_A, merged_B
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(2) :: kn
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(contrib_cache_outer) :: F, D, S
    type(QcMat) :: Zeta, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size
    
       do j = 1, 3
       
!           write(*,*) 'pids', deriv_struct(i, j)%pid
       
       
       end do

       merged_A = merge_p_tuple(p_tuple_a, deriv_struct(i,1))
       merged_B = merge_p_tuple(p_tuple_a, deriv_struct(i,3))

!        call sdf_getdata_s_2014(F, merged_A, get_fds_data_index(merged_A, &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(D, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!        call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)

       call contrib_cache_getdata_outer(F, 1, (/merged_A/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_A, &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)   
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B)
       call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)            
     
     
         
       
     

!        Zeta = Zeta + A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Zeta)   

!        call sdf_getdata_s_2014(F, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(S, merged_B, get_fds_data_index(merged_B, &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)
       
       call contrib_cache_getdata_outer(F, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)          
       call contrib_cache_getdata_outer(S, 1, (/merged_B/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_B, &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C)       
            


!        Zeta = Zeta - A * B * C

       call QcMatkABC(-1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Zeta)   

       if (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)
               
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)                     

!           Zeta = Zeta + ( ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,1)) + &
!                            frequency_zero_or_sum(deriv_struct(i,2)) ) * A * B * C

          call QcMatcABC(((1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,1)) + &
                           frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)   

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)

          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)  

!           Zeta = Zeta + ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,1)) * A * B * C
          
          call QcMatcABC(((1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,1)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)   

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,1)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), A)

          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A)                 

!           Zeta = Zeta + frequency_zero_or_sum(deriv_struct(i,2)) * A * B * C
          
          call QcMatcABC(frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)  

       end if

            

       
!        call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(D, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), B)
!        call sdf_getdata_s_2014(F, merged_B, get_fds_data_index(merged_B, &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)

     
       call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,1)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
       call contrib_cache_getdata_outer(D, 1, (/deriv_struct(i,2)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=B) 
       call contrib_cache_getdata_outer(F, 1, (/merged_B/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_B, &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C) 
            
!        Zeta = Zeta +  A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Zeta)  

!        call sdf_getdata_s_2014(S, merged_A, get_fds_data_index(merged_A, &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), A)
!        call sdf_getdata_s_2014(F, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!             total_num_perturbations, which_index_is_pid, indices_len, ind), C)
                 
       call contrib_cache_getdata_outer(S, 1, (/merged_A/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_A, &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
       call contrib_cache_getdata_outer(F, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C) 

!        Zeta = Zeta - A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(-1.0d0, T, Zeta)  

       if (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)
               
                    
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C) 

!           Zeta = Zeta - ( ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,3)) + &
!                         frequency_zero_or_sum(deriv_struct(i,2)) ) * A * B * C
                        
          call QcMatcABC(((-1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,3)) + &
                        frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)  

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)
               
          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C) 

!           Zeta = Zeta - ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,3)) * A * B * C
          
          call QcMatcABC(((-1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,3)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)  

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

!           call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
!                total_num_perturbations, which_index_is_pid, indices_len, ind), C)

          call contrib_cache_getdata_outer(S, 1, (/deriv_struct(i,3)/), .FALSE., contrib_size=1, &
               ind_len=indices_len, ind_unsorted=(/get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=C) 

!           Zeta = Zeta - frequency_zero_or_sum(deriv_struct(i,2)) * A * B * C

          call QcMatcABC(-1.0d0 * frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta) 

       end if

       call p_tuple_deallocate(merged_A)
       call p_tuple_deallocate(merged_B)
         
    end do

!     write(*,*) '1 pid', deriv_struct(1,1)%pid
!     write(*,*) '2 pid', deriv_struct(1,2)%pid
!     write(*,*) '3 pid', deriv_struct(1,3)%pid
    
    merged_p_tuple = merge_p_tuple(p_tuple_a, merge_p_tuple(deriv_struct(1,1), &
                     merge_p_tuple(deriv_struct(1,2), deriv_struct(1,3))))

    ! NOTE JAN 16: Does not seem likely that the skip condition will ever be met here: Any calculation
    ! of Zeta should already be "not skip" for this merged tuple
    if (kn_skip(merged_p_tuple%npert, &
        merged_p_tuple%pid, kn) .eqv. .FALSE.) then

!        A = zeromat
!        call mat_ensure_alloc(A)

!        call sdf_getdata_s_2014(F, merged_p_tuple, get_fds_data_index(merged_p_tuple, & 
!        total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       
       call contrib_cache_getdata_outer(F, 1, (/merged_p_tuple/), .FALSE., contrib_size=1, &
            ind_len=indices_len, ind_unsorted=(/get_fds_data_index(merged_p_tuple, & 
       total_num_perturbations, which_index_is_pid, indices_len, ind)/), mat_sing=A) 
            


!        Zeta = Zeta - A
       
       call QcMatRAXPY(-1.0d0, A, Zeta)         

    end if

    call p_tuple_deallocate(merged_p_tuple)

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine






! END NEW 2015
  
  
  
  
  
  
! BEGIN NEW 2014

subroutine rsp_get_matrix_w_2014(superstructure_size, &
           deriv_struct, total_num_perturbations, which_index_is_pid, &
           indices_len, ind, F, D, S, W)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(sdf_2014) :: F, D, S
    type(QcMat) :: W, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size

       call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(F, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), B)
       call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!      W = W + A * B * C
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, W)
            


       if (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

          call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)
          call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), B)
          call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!            W = W + ((1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) - &
!                                    frequency_zero_or_sum(deriv_struct(i,3))) * A * B * C
               
          call QcMatcABC(((1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) - &
                        frequency_zero_or_sum(deriv_struct(i,3))), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, W)
               
         
       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

          call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)
          call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), B)
          call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!           W = W + ((1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)) * A * B * C
               
          call QcMatcABC(((1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, W)
               


       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,1)) == 0.0)) then

          call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)
          call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), B)
          call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!           W = W + ((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3))  * A * B * C

          call QcMatcABC(((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, W)   
          
       end if

    end do

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)

  end subroutine


  subroutine rsp_get_matrix_y_2014(superstructure_size, deriv_struct, &
           total_num_perturbations, which_index_is_pid, indices_len, &
           ind, F, D, S, Y)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(sdf_2014) :: F, D, S
    type(QcMat) :: Y, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)
    
    do i = 1, superstructure_size

       call sdf_getdata_s_2014(F, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(D, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), B)
       call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        Y = Y + A*B*C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Y)

       if (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)

!           Y = Y - frequency_zero_or_sum(deriv_struct(i,2)) * A * B * C

          call QcMatcABC(-1.0 * frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)
          
       end if

       call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(F, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        Y = Y - A * B * C
        
       call QcMatkABC(-1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Y)


       if (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then
          ! MaR: MAKE SURE THAT THESE (AND B) ARE ACTUALLY THE CORRECT 
          ! MATRICES TO USE HERE AND BELOW

          call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)
          call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)
               
!           Y = Y + ((-1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) + &
!                                     frequency_zero_or_sum(deriv_struct(i,3))) * A * B * C
                                    
          call QcMatcABC(((-1.0)/(2.0)) * (frequency_zero_or_sum(deriv_struct(i,1)) + &
                                    frequency_zero_or_sum(deriv_struct(i,3))), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)


       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
             (frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)
          call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!           Y = Y + ((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)) * A * B * C
          
          call QcMatcABC(((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,1)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)


       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,1)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)
          call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!           Y = Y + ((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3)) * A * B * C

          call QcMatcABC(((-1.0)/(2.0)) * frequency_zero_or_sum(deriv_struct(i,3)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Y)

       end if

    end do

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine


  subroutine rsp_get_matrix_z_2014(superstructure_size, deriv_struct, kn, &
           total_num_perturbations, which_index_is_pid, indices_len, &
           ind, F, D, S, Z)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    type(p_tuple) :: merged_p_tuple
    integer, dimension(2) :: kn
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(sdf_2014) :: F, D, S
    type(QcMat) :: Z, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size

       call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), B)
       call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        Z = Z + A*B*C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Z)

    end do

    merged_p_tuple = merge_p_tuple(deriv_struct(1,1), merge_p_tuple(deriv_struct(1,2), deriv_struct(1,3)))

    if (kn_skip(total_num_perturbations, merged_p_tuple%pid, kn) .eqv. .FALSE.) then


        call sdf_getdata_s_2014(D, merged_p_tuple, get_fds_data_index(merged_p_tuple, &
        total_num_perturbations, which_index_is_pid, indices_len, ind), A)

!         Z = Z - A
        
        call QcMatRAXPY(-1.0d0, A, Z)

    end if

    call p_tuple_deallocate(merged_p_tuple)

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine


  subroutine rsp_get_matrix_lambda_2014(p_tuple_a, superstructure_size, deriv_struct, &
           total_num_perturbations, which_index_is_pid, indices_len, ind, D, S, L)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple) :: p_tuple_a, merged_A, merged_B
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(sdf_2014) :: D, S
    type(QcMat) :: L, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size

       merged_A = merge_p_tuple(p_tuple_a, deriv_struct(i,1))
       merged_B = merge_p_tuple(p_tuple_a, deriv_struct(i,3))

       call sdf_getdata_s_2014(D, merged_A, get_fds_data_index(merged_A, &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(S, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), B)
       call sdf_getdata_s_2014(D, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)
       
!        L = L + A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, L)            
            

        
       call sdf_getdata_s_2014(D, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(D, merged_B, get_fds_data_index(merged_B, &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        L = L - A * B * C
       
       call QcMatkABC(-1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, L)    

       call p_tuple_deallocate(merged_A)
       call p_tuple_deallocate(merged_B)
       
    end do
    
    
    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine


  subroutine rsp_get_matrix_zeta_2014(p_tuple_a, kn, superstructure_size, deriv_struct, &
           total_num_perturbations, which_index_is_pid, indices_len, &
           ind, F, D, S, Zeta)

    implicit none

    integer :: i, total_num_perturbations, superstructure_size, indices_len
    type(p_tuple) :: p_tuple_a, merged_p_tuple, merged_A, merged_B
    type(p_tuple), dimension(superstructure_size, 3) :: deriv_struct
    integer, dimension(2) :: kn
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: ind
    type(sdf_2014) :: F, D, S
    type(QcMat) :: Zeta, A, B, C, T

    call QcMatInit(A)
    call QcMatInit(B)
    call QcMatInit(C)

    call QcMatInit(T)

    do i = 1, superstructure_size

       merged_A = merge_p_tuple(p_tuple_a, deriv_struct(i,1))
       merged_B = merge_p_tuple(p_tuple_a, deriv_struct(i,3))

       call sdf_getdata_s_2014(F, merged_A, get_fds_data_index(merged_A, &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(D, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), B)
       call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        Zeta = Zeta + A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Zeta)   

       call sdf_getdata_s_2014(F, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(S, merged_B, get_fds_data_index(merged_B, &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        Zeta = Zeta - A * B * C

       call QcMatkABC(-1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Zeta)   

       if (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)

!           Zeta = Zeta + ( ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,1)) + &
!                            frequency_zero_or_sum(deriv_struct(i,2)) ) * A * B * C

          call QcMatcABC(((1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,1)) + &
                           frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)   

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,1)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)

!           Zeta = Zeta + ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,1)) * A * B * C
          
          call QcMatcABC(((1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,1)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)   

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,1)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), A)

!           Zeta = Zeta + frequency_zero_or_sum(deriv_struct(i,2)) * A * B * C
          
          call QcMatcABC(frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)  

       end if

       call sdf_getdata_s_2014(S, deriv_struct(i,1), get_fds_data_index(deriv_struct(i,1), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(D, deriv_struct(i,2), get_fds_data_index(deriv_struct(i,2), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), B)
       call sdf_getdata_s_2014(F, merged_B, get_fds_data_index(merged_B, &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        Zeta = Zeta +  A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(1.0d0, T, Zeta)  

       call sdf_getdata_s_2014(S, merged_A, get_fds_data_index(merged_A, &
            total_num_perturbations, which_index_is_pid, indices_len, ind), A)
       call sdf_getdata_s_2014(F, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
            total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!        Zeta = Zeta - A * B * C
       
       call QcMatkABC(1.0d0, A, B, C, T)
       call QcMatRAXPY(-1.0d0, T, Zeta)  

       if (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0) .and. &
           .not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!           Zeta = Zeta - ( ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,3)) + &
!                         frequency_zero_or_sum(deriv_struct(i,2)) ) * A * B * C
                        
          call QcMatcABC(((-1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,3)) + &
                        frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)  

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,3)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,2)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!           Zeta = Zeta - ((1.0)/(2.0))*frequency_zero_or_sum(deriv_struct(i,3)) * A * B * C
          
          call QcMatcABC(((-1.0d0)/(2.0d0))*frequency_zero_or_sum(deriv_struct(i,3)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta)  

       elseif (.not.(frequency_zero_or_sum(deriv_struct(i,2)) == 0.0) .and. &
                    (frequency_zero_or_sum(deriv_struct(i,3)) == 0.0)) then

          call sdf_getdata_s_2014(S, deriv_struct(i,3), get_fds_data_index(deriv_struct(i,3), &
               total_num_perturbations, which_index_is_pid, indices_len, ind), C)

!           Zeta = Zeta - frequency_zero_or_sum(deriv_struct(i,2)) * A * B * C

          call QcMatcABC(-1.0d0 * frequency_zero_or_sum(deriv_struct(i,2)), A, B, C, T)
          call QcMatRAXPY(1.0d0, T, Zeta) 

       end if

       call p_tuple_deallocate(merged_A)
       call p_tuple_deallocate(merged_B)
         
    end do

    merged_p_tuple = merge_p_tuple(p_tuple_a, merge_p_tuple(deriv_struct(1,1), &
                     merge_p_tuple(deriv_struct(1,2), deriv_struct(1,3))))

    if (kn_skip(merged_p_tuple%npert, &
        merged_p_tuple%pid, kn) .eqv. .FALSE.) then

!        A = zeromat
!        call mat_ensure_alloc(A)

       call sdf_getdata_s_2014(F, merged_p_tuple, get_fds_data_index(merged_p_tuple, & 
       total_num_perturbations, which_index_is_pid, indices_len, ind), A)

!        Zeta = Zeta - A
       
       call QcMatRAXPY(-1.0d0, A, Zeta)         

    end if

    call p_tuple_deallocate(merged_p_tuple)

    call QcMatDst(A)
    call QcMatDst(B)
    call QcMatDst(C)
    call QcMatDst(T)


  end subroutine



! END NEW 2014
  
  
  function get_fds_data_index(pert_tuple, total_num_perturbations, which_index_is_pid, &
                              indices_len, indices)

    implicit none

    type(p_tuple) :: pert_tuple
    integer :: i, total_num_perturbations, indices_len
    integer, allocatable, dimension(:) :: get_fds_data_index
    integer, dimension(total_num_perturbations) :: which_index_is_pid
    integer, dimension(indices_len) :: indices

    if (pert_tuple%npert == 0) then

       allocate(get_fds_data_index(1))
       get_fds_data_index(1) = 1

    else

       allocate(get_fds_data_index(pert_tuple%npert))

       do i = 1, pert_tuple%npert

          get_fds_data_index(i) = indices(which_index_is_pid(pert_tuple%pid(i)))

       end do

    end if

  end function


  function frequency_zero_or_sum(pert_tuple)

    implicit none

    type(p_tuple) :: pert_tuple
    complex(8) :: frequency_zero_or_sum
    integer :: i

    frequency_zero_or_sum = 0.0

    if (pert_tuple%npert > 0) then

       do i = 1, pert_tuple%npert

          frequency_zero_or_sum = frequency_zero_or_sum + pert_tuple%freq(i)

       end do

    end if

  end function

end module

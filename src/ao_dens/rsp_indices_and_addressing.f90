! Copyright 2012 Magnus Ringholm
!
! This source code form is subject to the terms of the
! GNU Lesser General Public License, version 2.1.
! If a copy of the GNU LGPL v2.1 was not distributed with this
! code, you can obtain one at https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html.

! Contains routines and associated functions/definitions for the
! creation of indices and addressing of elements of the (collapsed)
! arrays used throughout the rsp_general calculation

module rsp_indices_and_addressing

  use rsp_field_tuple, only: p_tuple,         &
                             p_tuple_compare, &
                             p_tuple_getone,  &
                             p_tuple_deallocate
!  use matrix_defop, matrix => openrsp_matrix
!  use matrix_lowlevel, only: mat_init, mat_ensure_alloc
  use qcmatrix_f

  implicit none

  public get_one_tensor_offset
  public test_making_triangulated_indices
  public get_num_blks
  public get_blk_info_s
  public get_blk_info
  public get_triang_blks_tuple_offset
  public get_triang_blks_offset
  public get_triang_offset
  public sort_triangulated_indices
  public make_triangulated_tuples_indices
  public make_triangulated_indices
  public index_blks_direct_product
  public make_one_triang_index_blk
  public get_triangular_sizes
  public get_triangulated_size
  public get_one_triangular_size
  public fact_terminate_lower
  public make_one_index_tuple
  public get_ncarray
  public kn_skip
  public nc_only
  public nc_onlysmall
  public make_indices
  public make_outerwhichpert
  public get_pidoutersmall
  public sortdimbypid
  
  public mem_manager
  public mem_set_status
  public mem_incr
  public mem_decr
  public mem_enough
  public mem_exceed
  
  public QcMatInit
  public QcMatZero
  public QcMatcAB
  public QcMatkAB
  public QcMatcABC
  public QcMatkABC
  public QcMatAEqB
  public QcMatDst
  public QcMatTraceAB
  public QcMatTraceATrB
  public QcMatRAXPY
  
  ! Define memory management datatype
  
  type mem_manager
  
     logical :: calibrate = .FALSE.
     logical :: limited = .FALSE.
     
     integer :: curr_mat = 0
     integer :: max_mat = 2147483647
     integer :: max_recorded_mat = 0
     integer :: remain = 0
     integer :: status = 0
     integer, dimension(3) :: checkpoint = (/0,0,0/)
            
  end type
  

  ! Define triangulated index block datatype

  type triangulated_index_block

     integer, allocatable, dimension(:,:) :: t_ind

  end type

  private

  contains

  ! Memory management routines
  
  ! Set result of memory run
  ! In increasing order of severity:
  ! 0: Can be run without any restrictions
  ! 1: Can be run, but only with restrictions
  ! 2: Can not be run, even with restrictions
  ! Outcome can always be set to more severe, but never less
  subroutine mem_set_status(mgr, outcome)
  
    implicit none
    
    type(mem_manager) :: mgr
    integer :: outcome
    
    if (outcome > mgr%status) then
    
       mgr%status = outcome
    
    end if  
  
  end subroutine
  
  
  ! Increase "matrix in memory" counter
  ! If optional argument 'n' not specified, increment by 1
  ! If limit exceeded, mark as failed
  subroutine mem_incr(mgr, n, p)
  
    implicit none
    
    type(mem_manager) :: mgr
    integer :: n
    integer, dimension(3), optional :: p
    
    mgr%curr_mat = mgr%curr_mat + n
    
    mgr%remain = mgr%remain - n
    
    if (mgr%curr_mat > mgr%max_recorded_mat) then
    
        mgr%max_recorded_mat = mgr%curr_mat
    
!         write(*,*) ' '
!         write(*,*) 'New peak matrix usage:', mgr%max_recorded_mat
!         write(*,*) ' '
    
    end if
    
    if (mgr%limited) then
    
       if (mgr%curr_mat > mgr%max_mat) then
    
          ! If limit exceeded, record where it first happened
          if (present(p) .AND. mgr%status < 2) then

             mgr%checkpoint = p
          
          end if
    
          call mem_set_status(mgr, 2)
       
!           write(*,*) 'Memory limit exceeded'
          
          if (present(p)) then
          
!              write(*,*) 'Memory limit was surpassed at checkpoint', mgr%checkpoint
          
          end if
       
       end if
       
    end if
    

    
!     write(*,*) 'mat use increased by', n, ' to', mgr%curr_mat, ' remaining:', mgr%remain
        
  end subroutine
  
  ! Decrease "matrix in memory" counter
  ! If optional argument 'n' not specified, decrease by 1
  subroutine mem_decr(mgr, n)
  
    implicit none
    
    type(mem_manager) :: mgr
    integer :: n
    
    mgr%curr_mat = mgr%curr_mat - n
    
    mgr%remain = mgr%remain + n
    
!     write(*,*) 'mat use decreased by', n, ' to', mgr%curr_mat, ' remaining:', mgr%remain

  end subroutine
  
  ! Is there enough memory left if n more matrices are allocated?
  function mem_enough(mgr, n)
  
    implicit none
    
    type(mem_manager) :: mgr
    integer :: n
    logical :: mem_enough

    if (mgr%limited) then
    
       if (mgr%remain > n) then
    
          mem_enough = .TRUE.     
    
       else
    
          mem_enough = .FALSE.
    
       end if
    
    else
    
       mem_enough = .TRUE.
    
    end if
    
    
  end function
  
  ! Has the memory limit been exceeded?
  function mem_exceed(mgr)
  
    implicit none
    
    type(mem_manager) :: mgr
    logical :: mem_exceed
    
    if (mgr%status == 2) then
    
       mem_exceed = .TRUE.
       
    else
    
       mem_exceed = .FALSE.
       
    end if
    
    if (mem_exceed) then
    
!        write(*,*) 'MEMORY EXCEEDED: Current and maximum:', mgr%curr_mat, mgr%max_mat
       
    end if
    
    
  end function
  
  
  

  
  
 
  
  ! End memory management routines
  
  
  
  
  ! MaR: QcMatrix adapted routines to be separated into new module
  ! Gao: adds an optional matrix B for initializing the structure of A
  ! Initialize matrix
  subroutine QcMatInit(A, B)
  
    implicit none
    
    type(QcMat), intent(inout) :: A
    type(QcMat), optional, intent(in) :: B
    integer(kind=4) :: ierr
    
    ierr = QcMatCreate_f(A)
    if (present(B)) then
        ierr = QcMatDuplicate_f(B, COPY_PATTERN_ONLY, A)
        ierr = QcMatZeroEntries_f(A)
    end if
    
  end subroutine

  ! Zero the matrix A: A should be initialized by QcMatInit()
  subroutine QcMatZero(A)

    implicit none

    type(QcMat), intent(inout) :: A
    integer(kind=4) :: ierr

    ierr = QcMatZeroEntries_f(A)

  end subroutine
      
  ! Compute R = kA * B (k complex)
  subroutine QcMatcAB(k, A, B, R)
  
    implicit none
    
    type(QcMat) :: A, B, R
    integer(kind=4) :: ierr
    complex(8) :: k

    ierr = QcMatGEMM_f(MAT_NO_OPERATION, MAT_NO_OPERATION, (/dreal(k), dimag(k)/), A, B, (/0.0d0, 0.0d0/), R)

  end subroutine
  
  ! Compute R = kA * B * C (k real)
  subroutine QcMatkAB(k, A, B, R)
  
    implicit none
    
    type(QcMat) :: A, B, R
    integer(kind=4) :: ierr
    real(8) :: k
    
    ierr = QcMatAXPY_f((/k, 0.0d0/), B, A)
    ierr = QcMatAXPY_f((/k, 0.0d0/), A, R)
    
  end subroutine
  
  
  ! Compute R = kA * B * C (k complex)
  subroutine QcMatcABC(k, A, B, C, R)
  
    implicit none
    
    type(QcMat) :: A, B, C, R
    type(QcMat) T
    integer(kind=4) :: ierr
    complex(8) :: k
        
    call QcMatInit(T, A)

    ! T = kB * C
    ierr = QcMatGEMM_f(MAT_NO_OPERATION, MAT_NO_OPERATION, (/dreal(k), dimag(k)/), B, C, (/0.0d0, 0.0d0/), T)
    
    ! R = A * T
    ierr = QcMatGEMM_f(MAT_NO_OPERATION, MAT_NO_OPERATION, (/1.0d0, 0.0d0/), A, T, (/0.0d0, 0.0d0/), R)
    ierr = QcMatDestroy_f(T)

  end subroutine

  ! Compute R = kA * B * C (k real)
  subroutine QcMatkABC(k, A, B, C, R)
  
    implicit none
    
    type(QcMat) :: A, B, C, R
    type(QcMat) T
    integer(kind=4) :: ierr
    integer :: i
    real(8) :: k
        
    call QcMatInit(T, A)
    
    ierr = QcMatGEMM_f(MAT_NO_OPERATION, MAT_NO_OPERATION, (/k, 0.0d0/), B, C, (/0.0d0, 0.0d0/), T)
    ierr = QcMatGEMM_f(MAT_NO_OPERATION, MAT_NO_OPERATION, (/1.0d0, 0.0d0/), A, T, (/0.0d0, 0.0d0/), R)
    
    ierr = QcMatDestroy_f(T)
  
  end subroutine
  
  ! Take matrix B and copy it into A
  subroutine QcMatAEqB(A, B)
  
    implicit none
    
    type(QcMat) :: A, B
    integer(kind=4) :: ierr  

    ierr = QcMatDuplicate_f(B, COPY_PATTERN_AND_VALUE, A)
    
  end subroutine 
  
  ! Destroy matrix
  subroutine QcMatDst(A)
  
    implicit none
    
    type(QcMat) :: A
    integer(kind=4) :: ierr
    
    ierr = QcMatDestroy_f(A)
  
  end subroutine
  
  ! Get trace of matrix product
  subroutine QcMatTraceAB(A, B, t)
  
    implicit none
    
    type(QcMat) :: A, B
    complex(8) :: t
    real(8), dimension(2) :: t_ans
    integer(kind=4) :: ierr
    integer(kind=QINT) dim_block_a, dim_block_b
    
    ierr = QcMatGetDimBlock_f(A, dim_block_a)
    ierr = QcMatGetDimBlock_f(A, dim_block_b)
    ierr = QcMatGetMatProdTrace_f(A, B, MAT_NO_OPERATION, dim_block_a, t_ans)

    ! What is dimension of answer?
    t = cmplx(t_ans(1), t_ans(2))
  
  end subroutine

  ! Get trace of matrix product with transposed B
  subroutine QcMatTraceATrB(A, B, t)

    implicit none

    type(QcMat) :: A, B
    complex(8) :: t
    real(8), dimension(2) :: t_ans
    integer(kind=4) :: ierr
    integer(kind=QINT) dim_block_a, dim_block_b

    ierr = QcMatGetDimBlock_f(A, dim_block_a)
    ierr = QcMatGetDimBlock_f(A, dim_block_b)
    ierr = QcMatGetMatProdTrace_f(A, B, MAT_TRANSPOSE, dim_block_a, t_ans)

    ! What is dimension of answer?
    t = cmplx(t_ans(1), t_ans(2))

  end subroutine

  
  ! Compute B = kA + B (k real)
  subroutine QcMatRAXPY(k, A, B)
  
    implicit none
    
    type(QcMat) :: A, B
    integer(kind=4) :: ierr
    real(8) :: k
    
    ierr = QcMatAXPY_f((/k, 0.0d0/), A, B)
  
  end subroutine
  
  ! End QcMatrix adapted routines
  
  
  ! Get offset in one tensor for indices 'indices'  
  function get_one_tensor_offset(total_num_perturbations, indices, pids, dims)

    implicit none

    integer :: total_num_perturbations, i, get_one_tensor_offset
    integer, dimension(total_num_perturbations) ::  indices, pids, dims

    get_one_tensor_offset = 1

    do i = 1, total_num_perturbations

       get_one_tensor_offset = get_one_tensor_offset + &
       (indices(i)- 1)*product(dims(pids(i):total_num_perturbations))/dims(pids(i))

    end do

  end function

  ! Test routine, unsure if still in use, possibly take out
  subroutine test_making_triangulated_indices(fields)

    implicit none

    type(p_tuple) :: fields
    integer :: i, num_blks, triangulated_size
    integer, allocatable, dimension(:,:) :: blk_info, indices

    num_blks = get_num_blks(fields)

    allocate(blk_info(num_blks, 3))

    blk_info = get_blk_info(num_blks, fields)
    triangulated_size = get_triangulated_size(num_blks, blk_info)

    allocate(indices(triangulated_size, sum(blk_info(:,2))))

    call make_triangulated_indices(num_blks, blk_info, triangulated_size, indices)

    deallocate(blk_info)
    deallocate(indices)

  end subroutine

 ! Get number of unique perturbations ("blocks") in tuple 'fields'
 ! Assumes fields is sorted
  function get_num_blks(fields)

    implicit none

    integer :: i, curr_blk_start, get_num_blks
    type(p_tuple) :: fields
    type(p_tuple), allocatable, dimension(:) :: each_field

!     fields = p_tuple_standardorder(fields)

    allocate(each_field(fields%npert))

    do i = 1, fields%npert

       each_field(i) = p_tuple_getone(fields, i)

    end do

    curr_blk_start = 1
    get_num_blks = 1

    do i = 1, fields%npert

       if (p_tuple_compare(each_field(curr_blk_start),each_field(i)) &
             .EQV. .FALSE.) then

          curr_blk_start = i
          get_num_blks = get_num_blks + 1

       end if

    end do

    deallocate(each_field)

  end function

  ! Subroutine to get various block information for perturbation tuple 'fields'
  ! Returns array of size (nblks, 3) where row 1 is curr_blk_start, row 2 is block_len
  ! row 3 is pdim
  subroutine get_blk_info_s(nblks, fields, blk_info)

    implicit none

    integer :: nblks, i, this_blk, curr_blk_start
    integer, dimension(nblks,3) :: blk_info   
    type(p_tuple) :: fields
    type(p_tuple), allocatable, dimension(:) :: each_field

    allocate(each_field(fields%npert))

    if (fields%npert > 0) then

       do i = 1, fields%npert

          each_field(i) = p_tuple_getone(fields, i)

       end do

       this_blk = 1
       curr_blk_start = 1
       blk_info(1, 1) = 1
       blk_info(1, 3) = each_field(1)%pdim(1)

       do i = 1, fields%npert

          if (p_tuple_compare(each_field(curr_blk_start),each_field(i)) &
             .EQV. .FALSE.) then

             curr_blk_start = i
             this_blk = this_blk + 1
             blk_info(this_blk, 1) = i
             blk_info(this_blk - 1, 2) = i - blk_info(this_blk - 1, 1)
             blk_info(this_blk, 3) = each_field(i)%pdim(1)

          end if

       end do

       if (nblks > 1) then

          blk_info(nblks, 2) = fields%npert - blk_info(nblks, 1) + 1

       elseif (nblks == 1) then

          blk_info(1, 2) = fields%npert

       end if

       do i = 1, fields%npert

          call p_tuple_deallocate(each_field(i))

       end do

    else

       blk_info(1, 1) = 1
       blk_info(1, 2) = 1
       blk_info(1, 3) = 1

    end if

    deallocate(each_field)

  end subroutine

  
  ! Function to get various block information for perturbation tuple 'fields'
  ! Returns array of size (nblks, 3) where row 1 is curr_blk_start, row 2 is block_len
  ! row 3 is pdim
  function get_blk_info(nblks, fields)

    implicit none

    integer :: nblks, i, this_blk, curr_blk_start
    integer, dimension(nblks,3) :: get_blk_info   
    type(p_tuple) :: fields
    type(p_tuple), allocatable, dimension(:) :: each_field

    allocate(each_field(fields%npert))

    if (fields%npert > 0) then

       do i = 1, fields%npert

          each_field(i) = p_tuple_getone(fields, i)

       end do

       this_blk = 1
       curr_blk_start = 1
       get_blk_info(1, 1) = 1
       get_blk_info(1, 3) = each_field(1)%pdim(1)

       do i = 1, fields%npert

          if (p_tuple_compare(each_field(curr_blk_start),each_field(i)) &
             .EQV. .FALSE.) then

             curr_blk_start = i
             this_blk = this_blk + 1
             get_blk_info(this_blk, 1) = i
             get_blk_info(this_blk - 1, 2) = i - get_blk_info(this_blk - 1, 1)
             get_blk_info(this_blk, 3) = each_field(i)%pdim(1)

          end if

       end do

       if (nblks > 1) then

          get_blk_info(nblks, 2) = fields%npert - get_blk_info(nblks, 1) + 1

       elseif (nblks == 1) then

          get_blk_info(1, 2) = fields%npert

       end if

       do i = 1, fields%npert

          call p_tuple_deallocate(each_field(i))

       end do

    else

       get_blk_info(1, 1) = 1
       get_blk_info(1, 2) = 1
       get_blk_info(1, 3) = 1

    end if

    deallocate(each_field)

  end function

  
  ! Get offset (non-redundant) for indices 'inds' in tuple of tuple of 
  ! perturbations as specified by collected block information
  function get_triang_blks_tuple_offset(ntuple, total_num_perturbations, nblks_tuple, &
                                        nfields, blks_info, &
                                        blk_sizes, blks_sizes, inds) result(offset)

    implicit none

    integer :: ntuple, offset, total_num_perturbations, i, k
    integer, dimension(ntuple) :: nblks_tuple, nfields, blks_sizes
    integer, dimension(ntuple, total_num_perturbations, 3) :: blks_info
    integer, dimension(ntuple, total_num_perturbations) :: blk_sizes
    integer, dimension(sum(nfields)) :: inds
    
    offset = 0
    k = 1
    
    do i = 1, ntuple - 1

       offset = offset + (get_triang_blks_offset(nblks_tuple(i), nfields(i), &
                         blks_info(i,1:nblks_tuple(i),:), &
                         blk_sizes(i, 1:nblks_tuple(i)),  &
                         inds(k:k + nfields(i) - 1))  - 1 )* &
                         (product(blks_sizes(i:ntuple))/blks_sizes(i))
       k = k + nfields(i)

    end do
    
    offset = offset + get_triang_blks_offset(nblks_tuple(ntuple), nfields(ntuple), &
                      blks_info(ntuple,1:nblks_tuple(ntuple),:), &
                      blk_sizes(ntuple, 1:nblks_tuple(ntuple)),  &
                      inds(k:k + nfields(ntuple) - 1))
                      
  end function


  ! Get offset (non-redundant) for indices 'ind_unsorted', in tuple of perturbations
  ! as specified by collected block information
  function get_triang_blks_offset(nblks, nfield, blk_info, blk_sizes, ind_unsorted) &
           result(offset)

    implicit none

    integer :: nblks, nfield, i, offset
    integer, dimension(nblks) :: blk_sizes
    integer, dimension(nblks, 3) :: blk_info
    integer, dimension(nfield) :: ind, ind_unsorted

    offset = 0

    ind = sorted_triangulated_indices(nfield, nblks, blk_info, ind_unsorted)

    do i = 1, nblks - 1

       offset = offset + (get_triang_offset(blk_info(i,2), &
       ind(blk_info(i,1): blk_info(i,1) + blk_info(i,2) - 1), blk_info(i,3)) - 1)* &
                            product(blk_sizes(i:nblks))/blk_sizes(i)

    end do

    offset = offset + get_triang_offset(blk_info(nblks,2), &
             ind(blk_info(nblks,1): blk_info(nblks,1) + blk_info(nblks,2) - 1), &
             blk_info(nblks,3))

  end function


  ! Get offset for one block taken from one perturbation tuple
  function get_triang_offset(nfield, ind, pdim) result(offset)

    implicit none

    integer :: i, offset, nfield, pdim
    integer, dimension(nfield) :: ind

    offset = 1

    if (nfield > 1) then

       offset = offset + get_one_way_triang_offset(nfield - 1, ind(1) - 1, pdim)

       do i = 2, nfield - 1

          offset = offset + get_one_way_triang_offset(nfield - i, ind(i) - ind(i - 1), &
                            pdim - ind(i - 1) + 1)

       end do

       offset = offset + ind(nfield) - ind(nfield - 1)

    else 

       offset = ind(1)

    end if

  end function


  ! Get offset par corresponding to one way of one block taken from one
  ! perturbation tuple
  function get_one_way_triang_offset(remaining, ind, pdim) result(offset)

    implicit none

    integer :: remaining, ind, pdim, offset, i

    offset = 0

    do i = 0, ind - 1

       offset = offset + fact_terminate_lower(pdim - i + remaining - 1, pdim - i) / &
                         fact_terminate_lower(remaining, 1)

    end do

  end function


  ! Function: Make sorted non-redundant indices from 'indices'
  function sorted_triangulated_indices(nfield, nblks, blk_info, indices)

    implicit none

    integer :: nfield, nblks, i, j, k, m, current_way, current_blk_start
    integer :: current_minimum_index_position, current_minimum_index, ind_tmp
    integer, dimension(nblks, 3) :: blk_info
    integer, dimension(nfield) :: indices, sorted_triangulated_indices

    current_blk_start = 1

    m = 0

    do i = 1, nblks

       do j = 1, blk_info(i, 2)

          current_minimum_index_position = j + m
          current_minimum_index = indices(j + m)

          do k = j + 1, blk_info(i, 2)
   
             if (indices(k + m) < current_minimum_index) then

                current_minimum_index = indices(k + m)
                current_minimum_index_position = k + m

             end if

          end do

          ind_tmp = indices(j + m)
          indices(j + m) = current_minimum_index
          indices(current_minimum_index_position) = ind_tmp      

       end do

       m = m + blk_info(i, 2)

    end do

    sorted_triangulated_indices = indices

  end function


  ! Subroutine: Make sorted non-redundant indices from 'indices'
  subroutine sort_triangulated_indices(nfield, nblks, blk_info, indices)

    implicit none

    integer :: nfield, nblks, i, j, k, m, current_way, current_blk_start
    integer :: current_minimum_index_position, current_minimum_index, ind_tmp
    integer, dimension(nblks, 3) :: blk_info
    integer, dimension(nfield) :: indices, sorted_indices

    current_blk_start = 1
    m = 0

    do i = 1, nblks

       do j = 1, blk_info(i, 2)

          current_minimum_index_position = j + m
          current_minimum_index = indices(j + m)

          do k = j + 1, blk_info(i, 2)
   
             if (indices(k + m) < current_minimum_index) then

                current_minimum_index = indices(k + m)
                current_minimum_index_position = k + m

             end if

          end do

          ind_tmp = indices(j + m)
          indices(j + m) = current_minimum_index
          indices(current_minimum_index_position) = ind_tmp      

       end do

       m = m + blk_info(i, 2)

    end do

  end subroutine


  ! Make nonredundant indices for tuple of tuple of perturbations, specified
  ! by collected block information
  subroutine make_triangulated_tuples_indices(ntuples, total_num_perturbations, &
           nblks_tuple, blks_tuple_info, &
           blks_tuple_triang_size, indices)

    implicit none

    integer :: i, ntuples, total_num_perturbations
    integer, dimension(ntuples) :: nblks_tuple, blks_tuple_triang_size
    integer, dimension(ntuples, total_num_perturbations, 3) :: blks_tuple_info
    integer, dimension(product(blks_tuple_triang_size), & 
             total_num_perturbations) :: indices
    type(triangulated_index_block), allocatable, &
         dimension(:) :: individual_block_tuple_indices

    allocate(individual_block_tuple_indices(ntuples))

    do i = 1, ntuples

       allocate(individual_block_tuple_indices(i)%t_ind(blks_tuple_triang_size(i), &
                sum(blks_tuple_info(i,1:nblks_tuple(i),2))))

       call make_triangulated_indices(nblks_tuple(i), &
            blks_tuple_info(i,1:nblks_tuple(i),:), blks_tuple_triang_size(i), &
            individual_block_tuple_indices(i)%t_ind)

    end do

    call index_blks_direct_product(ntuples, blks_tuple_triang_size, &
         individual_block_tuple_indices, indices, &
         sum((/ (blks_tuple_info(i,1:nblks_tuple(i),2), i = 1, ntuples) /)), &
         1, 1, 1)

    do i = 1, ntuples

       deallocate(individual_block_tuple_indices(i)%t_ind)

    end do

    deallocate(individual_block_tuple_indices)

  end subroutine

  ! Make nonredundant indices for tuple of perturbations
  subroutine make_triangulated_indices(nblks, blk_info, triangulated_size, indices)

    implicit none

    integer :: nblks, i, triangulated_size, j
    integer, dimension(nblks) :: triang_sizes
    integer, dimension(nblks, 3) :: blk_info
    integer, dimension(triangulated_size, sum(blk_info(:,2))) :: indices
    type(triangulated_index_block), allocatable, dimension(:) :: blks

    allocate(blks(nblks))

    do i = 1, nblks

       triang_sizes(i) = get_one_triangular_size(blk_info(i, 2), blk_info(i,3))

       allocate(blks(i)%t_ind(triang_sizes(i), blk_info(i, 2)))

       call make_one_triang_index_blk(blk_info(i, 2), blk_info(i, 3), 1, 1, 1, &
                                      triang_sizes(i), blks(i)%t_ind)

    end do

    call index_blks_direct_product(nblks, triang_sizes, blks, indices, &
                                   sum(blk_info(:,2)), 1, 1, 1)

    do i = 1, nblks

       deallocate(blks(i)%t_ind)

    end do

    deallocate(blks)

  end subroutine

  
  ! Make direct product of one set of indices (corresponding to one block) to another 
  ! until recursion has processed all blocks in this way
  recursive subroutine index_blks_direct_product(nblks, blk_sizes, blks, indices, &
                       nways, current_way, lvl, offset)

    implicit none

    integer :: nblks, current_way, lvl, i, j, offset, increment, nways, new_offset
    integer, dimension(nblks) :: blk_sizes
    type(triangulated_index_block), dimension(nblks) :: blks
    integer, dimension(product(blk_sizes), nways) :: indices

    if (lvl < nblks) then

       increment = product(blk_sizes(lvl:nblks))/blk_sizes(lvl)

       do i = 0, blk_sizes(lvl) - 1

          do j = 0, increment - 1

             indices(offset + i * increment + j, &
                     current_way:current_way + size(blks(lvl)%t_ind, 2) - 1) = &
                     blks(lvl)%t_ind(i + 1, :)

          end do

          new_offset = offset + i * increment
          call index_blks_direct_product(nblks, blk_sizes, blks, indices, &
               nways, current_way + size(blks(lvl)%t_ind, 2), lvl + 1, new_offset)

       end do

    elseif (lvl == nblks) then

       do i = 0, blk_sizes(lvl) - 1

          indices(offset + i, current_way:current_way + size(blks(lvl)%t_ind, 2) - 1) = &
          blks(lvl)%t_ind(i + 1, :)

       end do

    end if

  end subroutine


  ! Make one set of indices for one block of perturbations
  recursive subroutine make_one_triang_index_blk(blk_size, pdim, st_ind, lvl, offset, &
                                                   triang_size, index_blk)

    implicit none

    integer :: blk_size, pdim, st_ind, lvl, i, j, offset, &
               triang_size, new_offset, increment
    integer, dimension(triang_size, blk_size) :: index_blk

    if (lvl < blk_size) then

       new_offset = offset

       do i = 0, pdim - st_ind

          increment = get_one_triangular_size(blk_size - lvl, pdim - st_ind - i + 1)
          index_blk(new_offset:new_offset + increment - 1, lvl) = & 
          (i + st_ind) * (/ (j/j, j = 1, increment)/)

          call make_one_triang_index_blk(blk_size, pdim, st_ind + i, lvl + 1, &
                                         new_offset, triang_size, index_blk)

          new_offset = new_offset + increment

       end do

    elseif (lvl == blk_size) then

       do i = 0, pdim - st_ind

          index_blk(offset + i, lvl) = i + st_ind

       end do

    end if

  end subroutine

  ! Get size of nonredundant representation of elements for one perturbation tuple
  ! specified by 'blk_nfield' and 'pdims'
  function get_triangular_sizes(nblks, blk_nfield, pdims) result(blk_sizes)

    implicit none

    integer :: i, nblks
    integer, dimension(nblks) :: blk_nfield, pdims, blk_sizes

    do i = 1, nblks

       blk_sizes(i) = get_one_triangular_size(blk_nfield(i), pdims(i))

    end do 

  end function


  ! Get size of nonredundant representation of elements for one perturbation tuple
  ! specified by 'blk_info'
  function get_triangulated_size(nblks, blk_info)

    implicit none

    integer :: nblks, i, get_triangulated_size
    integer, dimension(nblks, 3) :: blk_info

    get_triangulated_size = 1

    do i = 1, nblks

       get_triangulated_size = get_triangulated_size * & 
                               get_one_triangular_size(blk_info(i, 2), blk_info(i, 3))

    end do

  end function


  ! Get (non-redundant) size of one block
  function get_one_triangular_size(blk_size, pdim)

    implicit none

    integer :: get_one_triangular_size, blk_size, pdim

    get_one_triangular_size = fact_terminate_lower(pdim + blk_size - 1, pdim) / &
                              fact_terminate_lower(blk_size,  1)

  end function

  ! Calculate the factorial quotient (highest)!/(lowest)!
  recursive function fact_terminate_lower(highest, lowest) result(ftl)

    implicit none

    integer :: highest, lowest
    integer(8) :: ftl

    if (highest == lowest) then

       ftl = highest   

    else

       ftl = highest * fact_terminate_lower(highest - 1, lowest)

    end if

  end function


  ! Make one tuple of (non-redundant) indices from an index number
  ! "What are the indices of index # 'icomp_in' for this perturbation tuple?"
  function make_one_index_tuple(n_perturbations, pdim, icomp_in)

    implicit none

    integer :: n_perturbations, icomp, i, icomp_in
    integer, dimension(n_perturbations) :: pdim, make_one_index_tuple

    icomp = icomp_in - 1

    do i = 1, n_perturbations

       ! MaR: The integer division (rounding to nearest 
       !      lower integer) should make this work
       make_one_index_tuple(i) = icomp/(product(pdim(i:n_perturbations))/pdim(i)) + 1
       icomp = icomp - (make_one_index_tuple(i) - 1) * &
                       (product(pdim(i:n_perturbations))/pdim(i))

    end do

  end function


  ! Make array of number of components ordered by perturbation id for tuple of
  ! tuples of perturbations
  function get_ncarray(total_order, num_p_tuples, p_tuples)

    implicit none

    integer :: total_order, num_p_tuples, i, j, k
    integer, dimension(total_order) :: get_ncarray
    type(p_tuple), dimension(num_p_tuples) :: p_tuples

    do i = 1, total_order
       do j = 1, num_p_tuples
          do k = 1, p_tuples(j)%npert

             if (p_tuples(j)%pid(k) == i) then
                get_ncarray(i) = p_tuples(j)%pdim(k)
             end if

          end do
       end do

    end do

  end function


  ! Find out if kn rules dictate that this term should be skipped
  function kn_skip(n_perturbations, pertid, kn)

    implicit none

    logical :: kn_skip, p_tuple_hasfirst
    integer :: n_perturbations, i
    integer, dimension(n_perturbations) :: pertid
    integer, dimension(2) :: kn

    kn_skip = .FALSE.
    p_tuple_hasfirst = .FALSE.

    do i = 1, size(pertid)
       if (pertid(i) == 1) then
          p_tuple_hasfirst = .TRUE.
       end if
    end do

   
    if (p_tuple_hasfirst .eqv. .TRUE.) then

       if (kn(1) < size(pertid)) then

          kn_skip = .TRUE.

       end if

    else

       if (kn(2) < size(pertid)) then

          kn_skip = .TRUE.

       end if

    end if

  end function

  ! Get subset of number of components for only perturbation ids for
  ! a tuple of perturbation tuples (other positions get value 1)
  ! Unsure if still in use, maybe remove
  function nc_only(total_order, thisorder, num_p_tuples, p_tuples, ncarray)

    implicit none

    integer :: i, j, total_order, thisorder, num_p_tuples
    integer, dimension(total_order) :: ncarray
    integer, dimension(total_order) :: nc_only
    type(p_tuple), dimension(num_p_tuples) :: p_tuples

    do i = 1, size(ncarray)
       nc_only(i) = 1
    end do

    do i = 1, num_p_tuples
       do j = 1, p_tuples(i)%npert
          nc_only(p_tuples(i)%pid(j)) = ncarray(p_tuples(i)%pid(j))
       end do
    end do

  end function

  ! Get subset of number of components for only perturbation ids for
  ! a tuple of perturbation tuples
  ! Unsure if still in use, maybe remove 
  function nc_onlysmall(total_order, thisorder, num_p_tuples, p_tuples, ncarray)

    implicit none

    integer :: i, j, k, total_order, thisorder, num_p_tuples
    integer, dimension(total_order) :: ncarray
    integer, dimension(thisorder) :: nc_onlysmall
    type(p_tuple), dimension(num_p_tuples) :: p_tuples

    k = 1

    do i = 1, num_p_tuples
       do j = 1, p_tuples(i)%npert

          nc_onlysmall(k) = ncarray(p_tuples(i)%pid(j))
          k = k + 1

       end do
    end do

  end function

  ! Make indices for perturbation collections described by number of components
  recursive subroutine make_indices(tot_outer, lvl, ncarray, offset, outer_indices)

    implicit none

    integer :: i, j, k, tot_outer, lvl, offset
    integer, dimension(tot_outer) :: ncarray
    integer, dimension(product(ncarray), tot_outer) :: outer_indices

    k = 1

    if (tot_outer > 0) then
       do i = 1, ncarray(lvl)

          if (lvl < tot_outer) then

             call make_indices(tot_outer, lvl + 1, ncarray, &
             k + offset - 1, outer_indices)

          end if

          if (lvl <= tot_outer) then

             do j = 1, product(ncarray(lvl:size(ncarray)))/ncarray(lvl)

                outer_indices(k + offset, lvl) = i
                k = k + 1

             end do

          end if

       end do

    else

    end if

  end subroutine


  ! Make array to tell which position perturbation with a given ID is in
  ! Unused entries get value 0
  ! Unsure if still in use, maybe remove
  function make_outerwhichpert(total_num_perturbations, num_p_tuples, p_tuples)

    implicit none

    integer :: i, j, k, total_num_perturbations, num_p_tuples
    type(p_tuple), dimension(num_p_tuples) :: p_tuples
    integer, dimension(total_num_perturbations) :: make_outerwhichpert

    do i = 1, total_num_perturbations

       make_outerwhichpert(i) = 0

    end do

    k = 1

    do i = 2, num_p_tuples
       do j = 1, p_tuples(i)%npert

          make_outerwhichpert(p_tuples(i)%pid(j)) = k
          k = k + 1

       end do
    end do

  end function

  ! Make array to tell which position perturbation with a given ID is in
  ! Unsure if still in use, maybe remove
  function get_pidoutersmall(totouter, len_outer, o_orders)

    implicit none

    integer :: totouter, len_outer, i, j, k
    integer, dimension(totouter) :: get_pidoutersmall
    type(p_tuple), dimension(len_outer) :: o_orders

    k = 1

    do i = 1, len_outer
       do j = 1, o_orders(i)%npert

          get_pidoutersmall(k) = o_orders(i)%pid(j)
          k = k + 1

       end do
    end do

  end function


  ! Sort perturbation dimensions by perturbation ID
  ! Not sure if this routine still in use, maybe remove
  subroutine sortdimbypid(total_num_perturbations, totouter, pids, &
                          dims, dimsouter, whichs)

    implicit none

    integer :: totouter, total_num_perturbations, s, i, j, whichmax, whatmax
    integer, dimension(totouter) :: b, d, pids, dimsouter
    integer, dimension(total_num_perturbations) :: whichs, dims

    do i = 1, total_num_perturbations

       whichs(i) = 0

    end do

    whichmax = 1

    s = totouter
    j = totouter
    d = pids

    do while (j > 0)

       whatmax = 0

       ! At which index is the pid largest?

       do i = 1, s
          if (d(i) > whatmax) then

             ! It is currently largest at index i
             whatmax = d(i)
             whichmax = i

          end if
       end do

       ! Then, put the dimension of that pid at the current end of the array to be returned

       b(j) = dims(whatmax)

       ! j is the (current) highest outer index

       whichs(j) = whatmax
       j = j - 1
       d(whichmax) = 0

    end do

    dimsouter = b

  end subroutine

end module
